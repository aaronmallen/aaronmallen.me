# frozen_string_literal: true

module Admin
  module Operations
    class ListRecordLinks
      include Blog::Constants

      include Deps[record_link_queries: "links.repos.record_link_queries"]

      def call(kind, id, query: nil, errors: EMPTY_HASH, except: EMPTY_ARRAY)
        links = record_link_queries.for_record(kind, id)
        query = Blog::Types::TrimmedText[query]

        { links:, query:, errors:, found: found(query, except, taken(kind, id, links)) }
      end

      private

      def found(query, except, taken)
        record_link_queries.find(query).except(*except).filter_map do |kind, rows|
          rows = rows.reject { taken.include?([kind, it.id]) }

          [kind, rows] unless rows.empty?
        end.to_h
      end

      def taken(kind, id, links) = links.flat_map { |other, rows| rows.map { [other, it.id] } }.push([kind, id])
    end
  end
end
