# frozen_string_literal: true

module Record
  module Queries
    class JournalEntryCount
      include Deps[journal_entry_repo: "repos.journal_entry_repo"]

      def call = journal_entry_repo.count
    end
  end
end
