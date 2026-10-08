# frozen_string_literal: true

module Admin
  module Operations
    class SearchPalette
      PAGE = Blog::Structs::Page.new(number: 1, size: 8)

      include Deps["operations.link_search_hit", search_queries: "search.repos.search_queries"]

      def call(text)
        search_queries.search(text:, page: PAGE).rows.map do |hit|
          { kind: hit.kind, id: hit.source_id, title: hit.title, match: hit.match, href: link_search_hit.call(hit) }
        end
      end
    end
  end
end
