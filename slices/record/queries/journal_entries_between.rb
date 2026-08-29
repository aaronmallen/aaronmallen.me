# frozen_string_literal: true

module Record
  module Queries
    class JournalEntriesBetween
      include Deps[journal_entry_repo: "repos.journal_entry_repo"]

      def call(from:, to:, **) = journal_entry_repo.between(from:, to:, **)
    end
  end
end
