# frozen_string_literal: true

module Record
  module Queries
    class JournalDays
      include Deps[journal_entry_repo: "repos.journal_entry_repo"]

      def call(size:, to: nil, **search)
        found = journal_entry_repo.by_day(size:, to:, **search)

        Blog::DayPaged.new(
          rows: found.rows.group_by(&:entry_date).to_a,
          newer_query: to && newer_query(to, size, search),
          older_query: found.continue_to && Blog::DayPaged.query(found.continue_to),
        )
      end

      private

      def newer_day(days, size)
        day = days[size - 1]
        overflow = days[days.count(days.first) + size - 1]

        overflow && overflow <= day ? overflow - 1 : day
      end

      def newer_query(to, size, search)
        days = journal_entry_repo.days_after(to, limit: size * 2, **search)
        return if days.empty?

        Blog::DayPaged.query(days.length > size ? newer_day(days, size) : nil)
      end
    end
  end
end
