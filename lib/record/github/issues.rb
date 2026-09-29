# frozen_string_literal: true

module Record
  module GitHub
    module Issues
      module Queries
        ASSIGNED_SEARCH = "is:issue is:open assignee:@me sort:created-asc"
        MAX_ASSIGNEES = 10
        PAGE_SIZE = 100

        FIELDS = <<~GRAPHQL.freeze
          ... on Issue {
            id url title body state stateReason
            repository { nameWithOwner }
            assignees(first: #{MAX_ASSIGNEES}) { nodes { id } }
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
      URL = %r{\Ahttps://github\.com/(?<repo>[^/]+/[^/]+)/issues/(?<number>\d+)\z}

      def assigned_issues
        return unless configured?

        walk do |cursor, found|
          data = transport.query(Queries::ASSIGNED, cursor:)
          page = data&.dig("search")
          page&.fetch("nodes")&.each { found << issue(it, data.dig("viewer", "id")) if it&.key?("id") }
          page
        end
      end

      def issues(urls)
        return unless configured?

        urls.keys.each_slice(ID_BATCH_SIZE).flat_map { issue_batch(it, urls) }
      end

      private

      def issue(node, viewer)
        {
          body: node["body"].to_s, id: node.fetch("id"), remote_state: remote_state(node, viewer),
          repo: node.dig("repository", "nameWithOwner"), title: node.fetch("title"), url: node.fetch("url"),
        }
      end

      def issue_batch(ids, urls)
        data = transport.query(Queries::BY_ID, ids:)
        viewer = data&.dig("viewer", "id") || raise(Client::Error, "GitHub sent no viewer id")

        ids.zip(data.fetch("nodes")).map do |id, node|
          node&.key?("id") ? issue(node, viewer) : vanished(id, urls.fetch(id))
        end
      end

      def moved_to(url)
        found = URL.match(url)

        found && transport.get("/repos/#{found[:repo]}/issues/#{found[:number]}")&.fetch("html_url", nil)
      end

      def remote_state(node, viewer)
        return UNASSIGNED unless node.dig("assignees", "nodes").to_a.any? { it["id"] == viewer }
        return OPEN unless node.fetch("state") == "CLOSED"

        CLOSE_REASONS.fetch(node["stateReason"], COMPLETED)
      end

      def vanished(id, url)
        found_at = moved_to(url)
        return { id:, remote_state: DELETED, url: } if found_at.nil? || found_at == url

        { id:, moved_to: found_at, remote_state: MOVED, url: }
      end
    end
  end
end
