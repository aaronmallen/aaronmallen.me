# frozen_string_literal: true

module Record
  module Linear
    module History
      module Queries
        PAGE_SIZE = 50

        FIELDS = <<~GRAPHQL
          pageInfo { hasNextPage endCursor }
          nodes { createdAt fromState { type } toState { type } }
        GRAPHQL

        BY_ID = <<~GRAPHQL.freeze
          query($ids: [ID!]!) {
            issues(first: #{Issues::ID_BATCH_SIZE}, includeArchived: true, filter: {id: {in: $ids}}) {
              nodes { id history(first: #{PAGE_SIZE}) { #{FIELDS} } }
            }
          }
        GRAPHQL

        OLDER = <<~GRAPHQL.freeze
          query($id: String!, $cursor: String) {
            issue(id: $id) { history(first: #{PAGE_SIZE}, after: $cursor) { #{FIELDS} } }
          }
        GRAPHQL
      end
      private_constant :Queries

      def transitions(issues, cursors)
        return unless configured?

        changed = issues.filter_map do |issue|
          id, updated_at = issue.values_at(:id, :updated_at)
          id if updated_at && cursors[id]&.<(updated_at)
        end

        transports.each_with_object({}) do |transport, seen|
          (changed - seen.keys).each_slice(Issues::ID_BATCH_SIZE) { seen.merge!(history_batch(transport, it, cursors)) }
        end
      end

      private

      def history(transport, id, page, since)
        found = page&.fetch("nodes").to_a
        return found unless more?(page) && found.all? { newer?(it, since) }

        found + older_history(transport, id, page.dig("pageInfo", "endCursor"), since).items
      end

      def history_batch(transport, ids, cursors)
        transport.query(Queries::BY_ID, ids:)&.dig("issues", "nodes").to_a.to_h do |node|
          id = node.fetch("id")
          since = cursors.fetch(id)

          [id, history(transport, id, node["history"], since).filter_map { transition(it, since) }.sort_by { it[:at] }]
        end
      end

      def newer?(entry, since) = Time.iso8601(entry.fetch("createdAt")) > since

      def older_history(transport, id, start, since)
        walk(start) do |cursor, found|
          page = transport.query(Queries::OLDER, id:, cursor:)&.dig("issue", "history")
          nodes = page&.fetch("nodes").to_a
          found.concat(nodes)
          page if nodes.all? { newer?(it, since) }
        end
      end

      def state_type(entry, side)
        type = entry.dig(side, "type")
        Issues::STATE_TYPES.fetch(type, Issues::OPEN) if type
      end

      def transition(entry, since)
        at = Time.iso8601(entry.fetch("createdAt"))
        from = state_type(entry, "fromState")
        to = state_type(entry, "toState")

        { at:, from:, to: } if at > since && from && to && from != to
      end
    end
  end
end
