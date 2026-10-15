# frozen_string_literal: true

module Record
  module Operations
    class UntagJournalEntry < Blog::TagOperation
      include Deps[
        mutations: "repos.journal_entry_mutations",
        queries: "repos.journal_entry_queries",
      ]

      private

      def change(id, name) = mutations.remove_tag(id, name)
    end
  end
end
