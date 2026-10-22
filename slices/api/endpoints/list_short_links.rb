# frozen_string_literal: true

module API
  module Endpoints
    class ListShortLinks < Endpoint
      FAILING = Blog::Types::ShortLinkFilter["failing"]

      SCHEMA = {
        additionalProperties: false,
        properties: {
          filter: {
            type: "string", enum: Blog::Types::ShortLinkFilter.values,
            description: "failing keeps the links whose destination fails the link check; all when left out",
          },
          sort: {
            type: "string", enum: Blog::Types::ShortLinkSort.values, description: "recent when left out",
          },
          page: Helpers::Paging::PAGE,
          query: { type: "string", description: "words to find in a link's title, destination or code" },
        },
      }.freeze

      REPLY = Helpers::Schema.paged(
        { count: Helpers::Schema::INTEGER, short_links: Helpers::Schema.list(Serializers::ShortLink.reference) },
      ).freeze

      include Deps[short_link_queries: "shares.repos.short_link_queries"]

      def handle(filter: nil, sort: Blog::Types::ShortLinkSort.values.first, page: 1, query: nil)
        found = { search: Blog::Types::OptionalText[query], failing: filter == FAILING }
        links = short_link_queries.page_listed(page_of(page), sort:, **found)

        Success(
          count: short_link_queries.count_listed(**found),
          short_links: serialized(Serializers::ShortLink, links.rows, settings:),
          **Helpers::Paging.fields(links),
        )
      end
    end
  end
end
