# frozen_string_literal: true

module Record
  module Jobs
    class RerenderJournalEntries < Blog::ScheduledJob
      include Deps[journal_entry_mutations: "repos.journal_entry_mutations"]

      def perform = journal_entry_mutations.rerender
    end
  end
end
