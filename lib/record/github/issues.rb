# frozen_string_literal: true

module Record
  module GitHub
    module Issues
      module Queries
        ASSIGNED_SEARCH = "is:issue is:open assignee:@me sort:created-asc"
        MAX_ASSIGNEES = 10
        MAX_COMMENTS = 100
        MAX_LABELS = 50
        MAX_RELATIONS = 100
        PAGE_SIZE = 100

        RELATED = "pageInfo { hasNextPage } nodes { id }"

        FIELDS = <<~GRAPHQL.freeze
          ... on Issue {
            id number url title body state stateReason
            repository { nameWithOwner }
            assignees(first: #{MAX_ASSIGNEES}) { nodes { id } }
            comments(first: #{MAX_COMMENTS}) { pageInfo { hasNextPage } nodes { id url body createdAt author { login } } }
            labels(first: #{MAX_LABELS}) { nodes { name } }
            blockedBy(first: #{MAX_RELATIONS}) { #{RELATED} }
            blocking(first: #{MAX_RELATIONS}) { #{RELATED} }
            parent { id }
            subIssues(first: #{MAX_RELATIONS}) { #{RELATED} }
          }
        GRAPHQL

        ASSIGNED = <<~GRAPHQL.freeze
          query($cursor: String) {
            viewer { id }
            search(query: "#{ASSIGNED_SEARCH}", type: ISSUE, first: #{PAGE_SIZE}, after: $cursor) {
              pageInfo { hasNextPage endCursor }
              nodes { #{FIELDS} }
            }
            rateLimit { limit remaining resetAt }
          }
        GRAPHQL

        BY_ID = <<~GRAPHQL.freeze
          query($ids: [ID!]!) {
            viewer { id }
            nodes(ids: $ids) { #{FIELDS} }
            rateLimit { limit remaining resetAt }
          }
        GRAPHQL
      end
      private_constant :Queries

      COMPLETED = Blog::Types::TaskSourceState["completed"]
      DELETED = Blog::Types::TaskSourceState["deleted"]
      MOVED = Blog::Types::TaskSourceState["moved"]
      NOT_PLANNED = Blog::Types::TaskSourceState["not_planned"]
      OPEN = Blog::Types::TaskSourceState["open"]
      UNASSIGNED = Blog::Types::TaskSourceState["unassigned"]

      CLOSE_REASONS = { "COMPLETED" => COMPLETED, "DUPLICATE" => NOT_PLANNED, "NOT_PLANNED" => NOT_PLANNED }.freeze
      ID_BATCH_SIZE = 100
      RELATIONS = { "blockedBy" => "blocked_by", "blocking" => "blocks", "subIssues" => "parent_of" }.freeze
      URL = %r{\Ahttps://github\.com/(?<repo>[^/]+/[^/]+)/issues/(?<number>\d+)\z}

      def assigned_issues
        return unless configured?

        walk { |cursor, found| assigned_page(cursor, found) }.items
      end

      def issues(urls)
        return unless configured?

        urls.keys.each_slice(ID_BATCH_SIZE).flat_map { issue_batch(it, urls) }
      end

      private

      def assigned_page(cursor, found)
        data = transport.query(Queries::ASSIGNED, cursor:)
        viewer = data&.dig("viewer", "id") || raise(Client::Error, "GitHub sent no viewer id")
        page = data["search"]
        page&.fetch("nodes")&.each { found << issue(it, viewer) if it&.key?("id") }
        page
      end

      def comment(node)
        { author: node.dig("author", "login"), body: node["body"].to_s,
          created_at: Time.iso8601(node.fetch("createdAt")), id: node.fetch("id"), url: node.fetch("url") }
      end

      def comments(node)
        page = node["comments"]

        { comments: page&.fetch("nodes").to_a.compact.map { comment(it) }, comments_cut_short: !whole?(page) }
      end

      def issue(node, viewer)
        origin = node.dig("repository", "nameWithOwner")

        {
          body: node["body"].to_s, **comments(node), id: node.fetch("id"), labels: labels(node), origin:,
          reference: "#{origin}##{node.fetch('number')}", remote_state: remote_state(node, viewer),
          title: node.fetch("title"), url: node.fetch("url"), **relations(node),
        }
      end

      def issue_batch(ids, urls)
        data = transport.query(Queries::BY_ID, ids:)
        viewer = data&.dig("viewer", "id") || raise(Client::Error, "GitHub sent no viewer id")

        ids.zip(data.fetch("nodes")).map do |id, node|
          node&.key?("id") ? issue(node, viewer) : vanished(id, urls.fetch(id))
        end
      end

      def labels(node) = node.dig("labels", "nodes").to_a.compact.map { it.fetch("name") }

      def moved_to(url)
        found = URL.match(url)

        found && transport.get("/repos/#{found[:repo]}/issues/#{found[:number]}")&.fetch("html_url", nil)
      end

      def related(node, field, kind) = node.dig(field, "nodes").map { { kind:, remote_id: it.fetch("id") } }

      def relations(node)
        return Blog::Constants::EMPTY_HASH unless RELATIONS.keys.all? { whole?(node[it]) }

        parent = node["parent"]
        found = RELATIONS.flat_map { |field, kind| related(node, field, kind) }

        { relations: parent ? [{ kind: "child_of", remote_id: parent.fetch("id") }, *found] : found }
      end

      def remote_state(node, viewer)
        return CLOSE_REASONS.fetch(node["stateReason"], COMPLETED) if node.fetch("state") == "CLOSED"

        node.dig("assignees", "nodes").to_a.any? { it["id"] == viewer } ? OPEN : UNASSIGNED
      end

      def vanished(id, url)
        found_at = moved_to(url)
        return { id:, remote_state: DELETED, url: } if found_at.nil? || found_at == url

        { id:, moved_to: found_at, remote_state: MOVED, url: }
      end

      def whole?(page) = !page.nil? && !more?(page) && page.fetch("nodes").none?(&:nil?)
    end
  end
end
