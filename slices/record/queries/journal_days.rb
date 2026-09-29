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

      def newer_query(to, size, search)
        days = journal_entry_repo.days_after(to, limit: size + 1, **search)
        return if days.empty?

        Blog::DayPaged.query(days.length > size ? days[size - 1] : nil)
      end
    end
  end
end
