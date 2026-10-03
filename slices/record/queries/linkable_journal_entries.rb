# frozen_string_literal: true

module Record
  module Queries
    class LinkableJournalEntries
      include Deps[journal_entry_repo: "repos.journal_entry_repo"]

      def matching(text, limit:) = journal_entry_repo.linkable(:journal_entries, text:, limit:)

      def named(ids) = journal_entry_repo.linkable(:journal_entries, ids:)
    end
  end
end
