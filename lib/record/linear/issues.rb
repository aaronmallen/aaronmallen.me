# frozen_string_literal: true

module Record
  module Linear
    module Issues
      module Queries
        CLOSED_TYPES = '["completed", "canceled"]'
        MAX_COMMENTS = 100
        MAX_LABELS = 50
        MAX_RELATIONS = 10
        PAGE_SIZE = 25
        RELATED = "pageInfo { hasNextPage } nodes"

        FIELDS = <<~GRAPHQL.freeze
          id identifier url title description trashed state { type } assignee { id }
          comments(first: #{MAX_COMMENTS}) { nodes { id url body createdAt user { displayName } } }
          labels(first: #{MAX_LABELS}) { nodes { name } }
          parent { id }
          children(first: #{MAX_RELATIONS}) { #{RELATED} { id } }
          relations(first: #{MAX_RELATIONS}) { #{RELATED} { type relatedIssue { id } } }
          inverseRelations(first: #{MAX_RELATIONS}) { #{RELATED} { type issue { id } } }
        GRAPHQL

        ASSIGNED = <<~GRAPHQL.freeze
          query($cursor: String) {
            viewer {
              id
              assignedIssues(
                first: #{PAGE_SIZE}
                after: $cursor
                orderBy: createdAt
                filter: {state: {type: {nin: #{CLOSED_TYPES}}}}
              ) {
                pageInfo { hasNextPage endCursor }
                nodes { #{FIELDS} }
              }
            }
          }
        GRAPHQL

        BY_ID = <<~GRAPHQL.freeze
          query($ids: [ID!]!) {
            viewer { id }
            issues(first: #{PAGE_SIZE}, includeArchived: true, filter: {id: {in: $ids}}) {
              nodes { #{FIELDS} }
            }
          }
        GRAPHQL
      end
      private_constant :Queries

      COMPLETED = Blog::Types::TaskSourceState["completed"]
      DELETED = Blog::Types::TaskSourceState["deleted"]
      NOT_PLANNED = Blog::Types::TaskSourceState["not_planned"]
      OPEN = Blog::Types::TaskSourceState["open"]
      STARTED = Blog::Types::TaskSourceState["started"]
      UNASSIGNED = Blog::Types::TaskSourceState["unassigned"]

      CLOSED = [COMPLETED, NOT_PLANNED].freeze
      ID_BATCH_SIZE = 25
      INVERSE_KINDS = { "blocks" => "blocked_by", "duplicate" => "duplicated_by", "related" => "relates" }.freeze
      KINDS = { "blocks" => "blocks", "duplicate" => "duplicates", "related" => "relates" }.freeze
      RELATIONS = %w[children relations inverseRelations].freeze
      STATE_TYPES = {
        "backlog" => OPEN, "canceled" => NOT_PLANNED, "completed" => COMPLETED, "started" => STARTED,
        "triage" => OPEN, "unstarted" => OPEN,
      }.freeze
      URL = %r{\Ahttps://linear\.app/(?<workspace>[^/]+)/issue/(?<team>[^/]+)-\d+(?:/|\z)}

      def assigned_issues
        return unless configured?

        transports.flat_map { assigned_in(it).items }
      end

      def issues(urls)
        return unless configured?

        found = transports.each_with_object({}) do |transport, seen|
          (urls.keys - seen.keys).each_slice(ID_BATCH_SIZE) { seen.merge!(issue_batch(transport, it)) }
        end

        urls.map { |id, url| found.fetch(id) { { id:, remote_state: DELETED, url: } } }
      end

      private

      def assigned_in(transport)
        walk do |cursor, found|
          viewer = transport.query(Queries::ASSIGNED, cursor:)&.dig("viewer")
          page = viewer&.dig("assignedIssues")
          page&.fetch("nodes")&.each { found << issue(it, viewer["id"]) }
          page
        end
      end

      def comment(node)
        { author: node.dig("user", "displayName"), body: node["body"].to_s,
          created_at: Time.iso8601(node.fetch("createdAt")), id: node.fetch("id"), url: node.fetch("url") }
      end

      def issue(node, viewer)
        key = node.fetch("identifier")
        url = node.fetch("url")

        {
          body: node["description"].to_s, comments: node.dig("comments", "nodes").to_a.compact.map { comment(it) },
          id: node.fetch("id"), key:, labels: labels(node), origin: origin(url, key), reference: key,
          remote_state: remote_state(node, viewer), title: node.fetch("title"), url:, **relations(node),
        }
      end

      def issue_batch(transport, ids)
        data = transport.query(Queries::BY_ID, ids:)
        viewer = data&.dig("viewer", "id") || raise(Client::Error, "Linear sent no viewer id")

        data.dig("issues", "nodes").to_a.to_h { [it.fetch("id"), issue(it, viewer)] }
      end

      def labels(node) = node.dig("labels", "nodes").to_a.compact.map { it.fetch("name") }

      def origin(url, key)
        workspace = url[URL, :workspace]
        team = key[/\A[^-]+(?=-\d+\z)/]

        "#{workspace}/#{team}" if workspace && team
      end

      def related(node, field, side, kinds)
        node.dig(field, "nodes").to_a.compact.filter_map do |relation|
          kind = kinds[relation["type"]]
          remote_id = relation.dig(side, "id")

          { kind:, remote_id: } if kind && remote_id
        end
      end

      def relations(node)
        return {} unless RELATIONS.all? { node[it] && !more?(node[it]) }

        parent = node.dig("parent", "id")
        children = node.dig("children", "nodes").to_a.compact.map { { kind: "parent_of", remote_id: it.fetch("id") } }

        { relations: [*([{ kind: "child_of", remote_id: parent }] if parent), *children,
                      *related(node, "relations", "relatedIssue", KINDS),
                      *related(node, "inverseRelations", "issue", INVERSE_KINDS)] }
      end

      def remote_state(node, viewer)
        return DELETED if node["trashed"]

        state = STATE_TYPES.fetch(node.dig("state", "type"), OPEN)
        return state if CLOSED.include?(state) || node.dig("assignee", "id") == viewer

        UNASSIGNED
      end
    end
  end
end
