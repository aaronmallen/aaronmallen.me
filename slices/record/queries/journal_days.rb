# frozen_string_literal: true

module Record
  module Queries
    class JournalDays
      include Deps[journal_entry_repo: "repos.journal_entry_repo"]

      def call(search: nil) = journal_entry_repo.by_day(search:)
    end
  end
end
