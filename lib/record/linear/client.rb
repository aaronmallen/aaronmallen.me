# frozen_string_literal: true

module Record
  module Linear
    class Client
      include Issues

      Error = Transport::Error
      RateLimited = Transport::RateLimited

      Listing = Data.define(:items, :cut_short) { def cut_short? = cut_short }
      private_constant :Listing

      MAX_PAGES = 10

      def initialize(transports:)
        @transports = transports
      end

      def configured? = transports.any?

      def inspect = "#<#{self.class.name} configured=#{configured?} workspaces=#{transports.size}>"

      private

      attr_reader :transports

      def merge(listings) = Listing.new(items: listings.flat_map(&:items), cut_short: listings.any?(&:cut_short?))

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
end
