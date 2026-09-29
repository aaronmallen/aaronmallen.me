# frozen_string_literal: true

module Record
  module Linear
    module Issues
      module Queries
        CLOSED_TYPES = '["completed", "canceled"]'
        PAGE_SIZE = 100

        FIELDS = "id identifier url title description trashed state { type } assignee { id }"

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

      ID_BATCH_SIZE = 100
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

      def issue(node, viewer)
        {
          body: node["description"].to_s, id: node.fetch("id"), key: node.fetch("identifier"),
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
