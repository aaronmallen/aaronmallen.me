# frozen_string_literal: true

module Record
  module Jobs
    class ImportCommits < Blog::ScheduledJob
      SYNC = Blog::Types::SyncName["commits"]

      include Deps[
        commit_mutations: "repos.commit_mutations",
        import_commits: "operations.import_commits",
        record_sync_outcome: "operations.record_sync_outcome",
      ]

      def perform
        result = record_crash(SYNC) { commit_mutations.with_import_lock { import_commits.call } }

        record_outcome(SYNC, result)
      end
    end
  end
end
