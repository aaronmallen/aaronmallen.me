# frozen_string_literal: true

module Record
  module Queries
    class JournalEntryById
      include Deps[journal_entry_repo: "repos.journal_entry_repo"]

      def call(id) = journal_entry_repo.by_id(id)
    end
  end
end
