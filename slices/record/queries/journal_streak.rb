# frozen_string_literal: true

module Record
  module Queries
    class JournalStreak
      include Deps[journal_entry_repo: "repos.journal_entry_repo"]

      def call(now: Time.now)
        { days: Repos::JournalEntryRepo::STREAK_DAYS, written: journal_entry_repo.streak(now:) }
      end
    end
  end
end
