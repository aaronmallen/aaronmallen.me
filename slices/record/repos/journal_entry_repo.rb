# frozen_string_literal: true

module Record
  module Repos
    class JournalEntryRepo < Blog::DB::Repo
      STREAK_DAYS = 30

      commands :create, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[created_at updated_at] } }
      commands update: :by_pk, use: :timestamps, plugins_options: { timestamps: { timestamps: %i[updated_at] } }
      commands delete: :by_pk

      def between(from:, to:, limit: nil)
        found = with_tags.between(from, to).newest_first

        (limit ? found.limit(limit) : found).to_a
      end

      def by_day(search: nil)
        query = search.to_s.strip
        entries = with_tags.newest_first
        entries = entries.matching(query) unless query.empty?
        entries.to_a.group_by(&:entry_date).to_a
      end

      def by_id(id) = with_tags.by_pk(id).one

      def count = journal_entries.count

      def replace_tags(id, names) = journal_entry_tags.replace(id, tags.claim(names).values_at(*names))

      def streak(now: Time.now)
        today = Blog::TimeZone.today(now)

        journal_entries.between(today - (STREAK_DAYS - 1), today).days_written
      end

      def today(now: Time.now) = with_tags.on(Blog::TimeZone.today(now)).newest_first.to_a

      def word_count = journal_entries.word_total

      private

      def with_tags = journal_entries.combine(:tags)
    end
  end
end
