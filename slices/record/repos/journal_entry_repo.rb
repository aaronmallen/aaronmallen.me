# frozen_string_literal: true

module Record
  module Repos
    class JournalEntryRepo < Blog::DB::Repo
      include Blog::Constants

      STREAK_DAYS = 30
      TAG_SCOPE = Blog::Types::TagScope["private"]

      stamped_commands :create, :update
      commands delete: :by_pk

      def between(from:, to:, limit: nil, tag: nil)
        found = searched(with_tags, tags: Array(tag)).between(from, to).newest_first

        (limit ? found.limit(limit) : found).to_a
      end

      def by_day(size:, to: nil, **search)
        entries = searched(with_tags, **search)
        oldest = entries.unordered.min(:entry_date)
        return Blog::DayCursor::Page.new(rows: EMPTY_ARRAY, continue_to: nil) unless oldest

        Blog::DayCursor.page(oldest, to, size:, day: :entry_date.to_proc) do |low, high, limit|
          found = entries.between(low, high).newest_first
          (limit ? found.limit(limit) : found).to_a
        end
      end

      def by_id(id) = with_tags.by_pk(id).one

      def count = journal_entries.count

      def days_after(day, limit:, **search)
        searched(journal_entries, **search).later_than(day).oldest_first.limit(limit).pluck(:entry_date)
      end

      def days_between(from, to) = journal_entries.between(from, to).days.pluck(:entry_date)

      def replace_tags(id, names)
        journal_entry_tags.replace(id, tags.claim(names, scope: TAG_SCOPE).values_at(*names))
      end

      def streak(now: Time.now)
        today = Blog::TimeZone.today(now)

        journal_entries.between(today - (STREAK_DAYS - 1), today).days_written
      end

      def today(now: Time.now) = with_tags.on(Blog::TimeZone.today(now)).newest_first.to_a

      def word_count = journal_entries.word_total

      private

      def searched(entries, tags: EMPTY_ARRAY, text: EMPTY_STRING)
        entries = entries.matching(text) unless text.empty?
        entries = entries.tagged(tags) unless tags.empty?
        entries
      end

      def with_tags = journal_entries.combine(:tags)
    end
  end
end
