# frozen_string_literal: true

module API
  module Endpoints
    class Search < Endpoint
      KINDS = Blog::Types::SearchKind.values.freeze

      SCHEMA = {
        additionalProperties: false,
        properties: {
          query: { type: "string", description: "the words to find; quote a phrase or put - before a word to skip it" },
          kind: { type: "string", enum: KINDS, description: "find only this kind; every kind when you leave it out" },
          page: Blog::Paging::PAGE,
        },
        required: %w[query],
      }.freeze

      REPLY = Schema.object(
        { count: Schema::INTEGER, results: Schema.list(Serializers::SearchHit.reference), partial: Schema::BOOLEAN },
        optional: { next_page: Schema::INTEGER },
      ).freeze

      include Deps["settings", search_queries: "search.repos.search_queries"]

      def handle(query:, kind: nil, page: 1)
        found = search_queries.search(text: query, page: page_of(page), kinds: kind ? [kind] : KINDS)
        results = serialized(Serializers::SearchHit, found.rows)

        Success(count: results.length, results:, **Blog::Paging.fields(found))
      end

      private

      def page_of(number) = Blog::Structs::Page.new(number:, size: settings.page_size[:admin])
    end
  end
end
