# frozen_string_literal: true

module API
  module Endpoints
    class ListShares < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          filter: { type: "string", enum: Blog::Types::ShareFilter.values, description: "all when left out" },
          page: Helpers::Paging::PAGE,
          query: { type: "string", description: "words to find in a share's file name, type or code" },
        },
      }.freeze

      REPLY = Helpers::Schema.paged(
        { count: Helpers::Schema::INTEGER, shares: Helpers::Schema.list(Serializers::Share.reference) },
      ).freeze

      include Deps[share_queries: "shares.repos.share_queries"]

      def handle(filter: Blog::Types::ShareFilter.values.first, page: 1, query: nil)
        found = { filter:, search: Blog::Types::TrimmedText[query].then { it.empty? ? nil : it } }
        shares = share_queries.page_listed(page_of(page), **found)

        Success(
          count: share_queries.count_listed(**found),
          shares: serialized(Serializers::Share, shares.rows, origin: share_origin),
          **Helpers::Paging.fields(shares),
        )
      end
    end
  end
end
