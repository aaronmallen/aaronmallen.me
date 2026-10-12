# frozen_string_literal: true

module Record
  module Operations
    class UntagJournalEntry < Blog::Operation
      include Deps[
        journal_entry_mutations: "repos.journal_entry_mutations",
        journal_entry_queries: "repos.journal_entry_queries",
      ]

      def call(id, name)
        transaction do
          step find(id)
          journal_entry_mutations.remove_tag(id, name)
          journal_entry_queries.by_id(id)
        end
      end

      private

      def find(id) = found(journal_entry_queries.by_id(id) && id)
    end
  end
end
