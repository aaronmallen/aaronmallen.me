# frozen_string_literal: true

module Record
  module Queries
    class JournalWordCount
      include Deps[journal_entry_repo: "repos.journal_entry_repo"]

      def call = journal_entry_repo.word_count
    end
  end
end
