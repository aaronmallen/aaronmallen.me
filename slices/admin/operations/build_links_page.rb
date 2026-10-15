# frozen_string_literal: true

module Admin
  module Operations
    class BuildLinksPage
      PAGE_SIZE = 15
      NO_ERRORS = Blog::Constants::EMPTY_HASH
      FAILING = Blog::Types::ShortLinkFilter["failing"]

      include Deps[short_link_queries: "shares.repos.short_link_queries"]

      def self.first_page = Blog::Structs::Page.new(number: 1, size: PAGE_SIZE)

      def call(page: self.class.first_page, params: nil, errors: NO_ERRORS, again: nil, **list)
        list = listed(**list)
        links = short_link_queries.page_listed(page, **query(list))

        {
          again:,
          checks: short_link_queries.checks(links.rows),
          count: short_link_queries.count_listed(search: list[:search], failing: failing?(list)),
          errors:,
          links:,
          list:,
          totals: short_link_queries.totals,
          values: values(params),
        }
      end

      private

      def failing?(list) = list[:filter] == FAILING

      def listed(sort: nil, filter: nil, search: nil)
        {
          sort: Blog::Types::ShortLinkSortParam[sort],
          filter: Blog::Types::ShortLinkFilterParam[filter],
          search: Blog::Types::OptionalText[search],
        }.compact
      end

      def query(list) = { sort: list[:sort], search: list[:search], failing: failing?(list) }

      def values(params)
        fields = Blog::Types::Fields[params]
        { destination: Blog::Types::Text[fields[:destination]], code: Blog::Types::Text[fields[:code]] }
      end
    end
  end
end
