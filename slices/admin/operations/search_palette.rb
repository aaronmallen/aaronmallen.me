# frozen_string_literal: true

module Admin
  module Operations
    class SearchPalette
      PER_KIND = 5
      PAGE = Blog::Structs::Page.new(number: 1, size: Blog::Types::SearchKind.values.size * PER_KIND)

      include Deps["i18n", "operations.link_search_hit", search_queries: "search.repos.search_queries"]

      def call(text)
        search_queries.search(text:, page: PAGE, per_kind: PER_KIND).rows.group_by(&:kind).map do |kind, hits|
          { kind:, hits: hits.map { entry(it) } }
        end
      end

      private

      def entry(hit)
        {
          id: hit.source_id, title: hit.title, match: hit.match, date: i18n.l(hit.day, format: :medium),
          href: link_search_hit.call(hit),
        }
      end
    end
  end
end
