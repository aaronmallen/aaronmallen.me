# frozen_string_literal: true

module Blog
  module CursorPaging
    Listing = Data.define(:items, :cut_short) { def cut_short? = cut_short }
    MAX_PAGES = 10

    private

    def more?(page) = page&.dig("pageInfo", "hasNextPage") == true

    def walk(cursor = nil, max_pages: MAX_PAGES)
      found = []
      page = nil
      seen = Set[cursor, nil]

      (1..max_pages).each do
        page = yield cursor, found
        break unless more?(page)

        cursor = page.dig("pageInfo", "endCursor")
        break unless seen.add?(cursor)
      end

      Listing.new(items: found, cut_short: more?(page))
    end
  end
end
