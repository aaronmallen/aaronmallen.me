# frozen_string_literal: true

module Record
  module Repos
    class JournalEntryQueries < Blog::DB::Repo
      include Blog::Constants

      STREAK_DAYS = 30

      def between(from:, to:, limit: nil, tag: nil)
        found = searched(with_tags, tags: Array(tag)).between(from, to).newest_first

        found.limit(limit).to_a
      end

      def by_id(id) = with_tags.by_pk(id).one

      def by_tag(tag) = with_tags.tagged([tag]).newest_first.to_a

      def count = journal_entries.count

      def days(size:, to: nil, **search)
        found = by_day(size:, to:, **search)

        Blog::Structs::DayPaged.new(
          rows: found.rows.group_by(&:entry_date).to_a,
          newer_query: to && newer_query(to, size, search),
          older_query: found.continue_to && Blog::Structs::DayPaged.query(found.continue_to),
        )
      end

      def days_between(from, to) = journal_entries.between(from, to).days.pluck(:entry_date)

      def streak(now: Time.now)
        today = Blog::TimeZone.today(now)

        { days: STREAK_DAYS, written: journal_entries.between(today - (STREAK_DAYS - 1), today).days_written }
      end

      def today(now: Time.now) = with_tags.on(Blog::TimeZone.today(now)).newest_first.to_a

      def word_count = journal_entries.word_total

      private

      def by_day(size:, to: nil, **search)
        entries = searched(with_tags, **search)
        oldest = entries.unordered.min(:entry_date)
        return Blog::Structs::DayCursor.new(rows: EMPTY_ARRAY, continue_to: nil) unless oldest

        Blog::Structs::DayCursor.page(oldest, to, size:, day: :entry_date.to_proc) do |low, high, limit|
          found = entries.between(low, high).newest_first
          found.limit(limit).to_a
        end
      end

      def days_after(day, limit:, **search)
        searched(journal_entries, **search).later_than(day).oldest_first.limit(limit).pluck(:entry_date)
      end

      def newer_day(days, size)
        day = days[size - 1]
        overflow = days[days.count(days.first) + size - 1]

        overflow && overflow <= day ? overflow - 1 : day
      end

      def newer_query(to, size, search)
        days = days_after(to, limit: size * 2, **search)
        return if days.empty?

        Blog::Structs::DayPaged.query(days.length > size ? newer_day(days, size) : nil)
      end

      def searched(entries, tags: EMPTY_ARRAY, text: EMPTY_STRING)
        entries = entries.matching(text) unless text.empty?
        entries = entries.tagged(tags) unless tags.empty?
        entries
      end

      def with_tags = journal_entries.combine(:tags)
    end
  end
end
