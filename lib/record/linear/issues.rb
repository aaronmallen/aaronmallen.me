# frozen_string_literal: true

module Record
  module Linear
    module Issues
      module Queries
        CLOSED_TYPES = '["completed", "canceled"]'
        MAX_COMMENTS = 100
        PAGE_SIZE = 25

        FIELDS = <<~GRAPHQL.freeze
          id identifier url title description trashed state { type } assignee { id }
          comments(first: #{MAX_COMMENTS}) { nodes { id url body createdAt user { displayName } } }
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

      ID_BATCH_SIZE = 25
      STATE_TYPES = {
        "backlog" => OPEN, "canceled" => NOT_PLANNED, "completed" => COMPLETED, "started" => STARTED,
        "triage" => OPEN, "unstarted" => OPEN,
      }.freeze

      def assigned_issues
        return unless configured?

        merge(transports.map { assigned_in(it) })
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

        {
          body: node["description"].to_s, comments: node.dig("comments", "nodes").to_a.compact.map { comment(it) },
          id: node.fetch("id"), key:, reference: key,
          remote_state: remote_state(node, viewer), title: node.fetch("title"), url: node.fetch("url"),
        }
      end

      def issue_batch(transport, ids)
        data = transport.query(Queries::BY_ID, ids:)
        viewer = data&.dig("viewer", "id") || raise(Client::Error, "Linear sent no viewer id")

        data.dig("issues", "nodes").to_a.to_h { [it.fetch("id"), issue(it, viewer)] }
      end

      def remote_state(node, viewer)
        return DELETED if node["trashed"]
        return UNASSIGNED unless node.dig("assignee", "id") == viewer

        STATE_TYPES.fetch(node.dig("state", "type"), OPEN)
      end
    end
  end
end
