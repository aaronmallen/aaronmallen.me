# frozen_string_literal: true

module Record
  module Jobs
    class ImportCommits < Blog::ScheduledJob
      SYNC = Blog::Types::SyncName["commits"]

      include Deps[
        commit_mutations: "repos.commit_mutations",
        import_commits: "operations.import_commits",
        record_sync_outcome: "operations.record_sync_outcome", # rubocop:disable Hanami/UnusedDeps
      ]

      def perform = record_outcome(SYNC, commit_mutations.with_import_lock { import_commits.call })
    end
  end
end
