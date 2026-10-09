# frozen_string_literal: true

module Record
  module GitHub
    module PullRequests
      module Queries
        PAGE_SIZE = 100
        SEARCH = "is:pr author:@me sort:updated-asc"

        AUTHORED = <<~GRAPHQL.freeze
          query($query: String!, $cursor: String) {
            search(query: $query, type: ISSUE, first: #{PAGE_SIZE}, after: $cursor) {
              issueCount
              pageInfo { hasNextPage endCursor }
              nodes {
                ... on PullRequest {
                  number title body url createdAt isDraft state mergedAt closedAt viewerDidAuthor
                  repository { nameWithOwner }
                  timelineItems(itemTypes: [READY_FOR_REVIEW_EVENT], last: 1) {
                    nodes { ... on ReadyForReviewEvent { createdAt } }
                  }
                }
              }
            }
            rateLimit { limit remaining resetAt }
          }
        GRAPHQL
      end
      private_constant :Queries

      FIRST_DAY = Time.utc(2008, 1, 1)
      SEARCH_CAP = Queries::PAGE_SIZE * Paging::MAX_PAGES

      def authored_pull_requests(updated_since: nil, now: Time.now) = authored_between(updated_since || FIRST_DAY, now)

      private

      def authored_between(from, to)
        query = "#{Queries::SEARCH} updated:#{stamp(from)}..#{stamp(to)}"
        first = pull_request_page(query, nil)
        return halves(from, to).flat_map { authored_between(*it) } if crowded?(first, from, to)

        listing = walk do |cursor, found|
          page = cursor ? pull_request_page(query, cursor) : first
          found.concat(authored_on(page))
          page
        end

        listing.items
      end

      def authored_on(page)
        nodes = page ? page.fetch("nodes") : Blog::Constants::EMPTY_ARRAY

        nodes.select { it&.fetch("viewerDidAuthor", false) }.map { pull_request(it) }
      end

      def crowded?(page, from, to) = page.to_h.fetch("issueCount", 0) > SEARCH_CAP && to - from > 1

      def halves(from, to)
        middle = from + ((to - from) / 2)

        [[from, middle], [middle, to]]
      end

      def pull_request(node)
        {
          body: node["body"].to_s,
          closed_at: node.fetch("state") == "CLOSED" ? read_time(node["closedAt"]) : nil,
          merged_at: read_time(node["mergedAt"]),
          number: node.fetch("number"),
          ready_at: ready_at(node),
          repo: node.dig("repository", "nameWithOwner"),
          title: node.fetch("title"),
          url: node.fetch("url"),
        }
      end

      def pull_request_page(query, cursor) = transport.query(Queries::AUTHORED, query:, cursor:)&.dig("search")

      def read_time(value) = value && Time.iso8601(value)

      def ready_at(node)
        return if node["isDraft"]

        read_time(node.dig("timelineItems", "nodes")&.last&.dig("createdAt") || node.fetch("createdAt"))
      end
    end
  end
end
