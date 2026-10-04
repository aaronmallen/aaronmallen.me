# frozen_string_literal: true

module Admin
  module Operations
    class ListRecordLinks
      include Blog::Constants

      include Deps[find_records: "links.queries.find_records", record_links: "links.queries.record_links"]

      def call(kind, id, query: nil, errors: EMPTY_HASH, except: EMPTY_ARRAY)
        links = record_links.call(kind, id)
        query = Blog::Types::TrimmedText[query]

        { links:, query:, errors:, found: found(query, except, taken(kind, id, links)) }
      end

      private

      def found(query, except, taken)
        find_records.call(query).except(*except).filter_map do |kind, rows|
          rows = rows.reject { taken.include?([kind, it.id]) }

          [kind, rows] unless rows.empty?
        end.to_h
      end

      def taken(kind, id, links) = links.flat_map { |other, rows| rows.map { [other, it.id] } }.push([kind, id])
    end
  end
end
