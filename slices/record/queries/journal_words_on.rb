# frozen_string_literal: true

module Record
  module Queries
    class JournalWordsOn
      include Deps[journal_entry_repo: "repos.journal_entry_repo"]

      def call(date) = journal_entry_repo.word_count(date:)
    end
  end
end
