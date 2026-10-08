# frozen_string_literal: true

module Record
  module Paging
    MAX_PAGES = 10

    private

    def more?(page) = page&.dig("pageInfo", "hasNextPage") == true

    def walk(cursor = nil)
      found = []
      page = nil

      MAX_PAGES.times do
        page = yield cursor, found
        break unless more?(page)

        cursor = page.dig("pageInfo", "endCursor")
      end

      Structs::Listing.new(items: found, cut_short: more?(page))
    end
  end
end
