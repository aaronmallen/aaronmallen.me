# frozen_string_literal: true

module Admin
  module Operations
    class BuildSearchPage
      include Deps["operations.link_search_hit", search_queries: "search.repos.search_queries"]

      def call(query:, kind:, page:)
        text = Blog::Types::TrimmedText[query]
        found = search_queries.search(text:, page:, kinds: kind ? [kind] : Blog::Types::SearchKind.values)

        {
          counts: search_queries.counts(text:),
          kind:,
          query: text,
          results: found.with(rows: found.rows.map { result(it) }),
        }
      end

      private

      def result(hit) = Structs::SearchResult.new(hit:, href: link_search_hit.call(hit))
    end
  end
end
