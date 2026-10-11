# frozen_string_literal: true

module Admin
  module Operations
    class BuildLinksPage
      PAGE_SIZE = 15
      NO_ERRORS = Blog::Constants::EMPTY_HASH

      include Deps[short_link_queries: "shares.repos.short_link_queries"]

      def self.first_page = Blog::Structs::Page.new(number: 1, size: PAGE_SIZE)

      def call(page: self.class.first_page, params: nil, errors: NO_ERRORS, again: nil, sort: nil, search: nil)
        list = { sort: Blog::Types::ShortLinkSortParam[sort], search: Blog::Types::OptionalText[search] }.compact

        {
          again:,
          count: short_link_queries.count_listed(search: list[:search]),
          errors:,
          links: short_link_queries.page_listed(page, **list),
          list:,
          totals: short_link_queries.totals,
          values: values(params),
        }
      end

      private

      def values(params)
        fields = Blog::Types::Fields[params]
        { destination: Blog::Types::Text[fields[:destination]], code: Blog::Types::Text[fields[:code]] }
      end
    end
  end
end
