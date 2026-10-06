# frozen_string_literal: true

module Record
  module Queries
    class JournalEntriesByTag
      include Deps[journal_entry_repo: "repos.journal_entry_repo"]

      def call(tag) = journal_entry_repo.by_tag(tag)
    end
  end
end
