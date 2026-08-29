# frozen_string_literal: true

module Record
  module Queries
    class JournalEntriesToday
      include Deps[journal_entry_repo: "repos.journal_entry_repo"]

      def call(now: Time.now) = journal_entry_repo.today(now:)
    end
  end
end
