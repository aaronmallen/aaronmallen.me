# frozen_string_literal: true

require "dry/monads"

module API
  module Queries
    class SavedViewJournal
      FIELDS = %i[tag].freeze

      include Dry::Monads[:result]
      include Deps[journal_entry_queries: "record.repos.journal_entry_queries"]

      def call(filters, continue_to: nil, **)
        search = Blog::SearchQuery.parse(filters["q"], fields: FIELDS)
        found = journal_entry_queries.days(size: Blog::DayWindow::CAP, to: last_day(filters, continue_to), **search)

        Success(rows: found.rows.flat_map(&:last), **paging(found.older_query))
      end

      private

      def last_day(filters, continue_to) = continue_to || Blog::Types::DateParam[filters["to"]]

      def paging(older) = older ? { partial: true, continue_to: older.fetch(:to) } : { partial: false }
    end
  end
end
