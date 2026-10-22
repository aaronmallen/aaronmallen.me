# frozen_string_literal: true

module API
  module Endpoints
    class Search < Endpoint
      KINDS = (Blog::Types::SearchKind.values - [Blog::Types::SearchKind["note"]]).freeze
      MESSAGE = Blog::Types::SearchKind["message"]
      SCOPED = true

      SCHEMA = {
        additionalProperties: false,
        properties: {
          query: { type: "string", description: "the words to find; quote a phrase or put - before a word to skip it" },
          kind: {
            type: "string",
            enum: KINDS,
            description: "find only this kind; every kind when you leave it out. message needs the mail scope",
          },
          page: Helpers::Paging::PAGE,
        },
        required: %w[query],
      }.freeze

      REPLY = Helpers::Schema.paged(
        {
          count: Helpers::Schema::INTEGER,
          results: Helpers::Schema.list(Serializers::SearchHit.reference),
        },
      ).freeze

      include Deps[search_queries: "search.repos.search_queries"]

      def handle(query:, scopes:, kind: nil, page: 1)
        refuse_mail(:kind, kind == MESSAGE, scopes) || searched(query, kind, scopes, page)
      end

      private

      def kinds(kind, scopes)
        chosen = kind ? [kind] : KINDS
        mail?(scopes) ? chosen : chosen - [MESSAGE]
      end

      def searched(query, kind, scopes, page)
        found = search_queries.search(text: query, page: page_of(page), kinds: kinds(kind, scopes))
        results = serialized(Serializers::SearchHit, found.rows)

        Success(count: results.length, results:, **Helpers::Paging.fields(found))
      end
    end
  end
end
