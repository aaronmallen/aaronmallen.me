# frozen_string_literal: true

module Record
  module Paging
    Listing = Data.define(:items, :cut_short) { def cut_short? = cut_short }
    private_constant :Listing

    MAX_PAGES = 10

    private

    def more?(page) = page&.dig("pageInfo", "hasNextPage") == true

    def walk
      found = []
      cursor = nil
      page = nil

      MAX_PAGES.times do
        page = yield cursor, found
        break unless more?(page)

        cursor = page.dig("pageInfo", "endCursor")
      end

      Listing.new(items: found, cut_short: more?(page))
    end
  end
end
