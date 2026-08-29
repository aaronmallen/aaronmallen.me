# frozen_string_literal: true

module Record
  module Operations
    class DeleteJournalEntry < Blog::Operation
      include Deps[journal_entry_repo: "repos.journal_entry_repo"]

      def call(id)
        step removed(id, journal_entry_repo.delete(id))
      end

      private

      def removed(id, entry) = entry ? Success(id) : Failure(:not_found)
    end
  end
end
