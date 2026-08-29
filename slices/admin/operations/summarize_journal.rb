# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeJournal
      include Deps[
        journal_days: "record.queries.journal_days",
        journal_entry_count: "record.queries.journal_entry_count",
        journal_streak: "record.queries.journal_streak",
        journal_word_count: "record.queries.journal_word_count",
      ]

      def call(search: Dry::Core::Constants::EMPTY_STRING, now: Time.now)
        {
          days: journal_days.call(search:),
          entries: journal_entry_count.call,
          streak: journal_streak.call(now:),
          today: Blog::TimeZone.today(now),
          words: journal_word_count.call,
        }
      end
    end
  end
end
