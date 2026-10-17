# frozen_string_literal: true

module Record
  module Jobs
    class ImportCommits < Blog::ScheduledJob
      SYNC = Blog::Types::SyncName["commits"]

      include SyncBookkeeping
      include Deps["operations.import_commits", "repos.commit_mutations"]

      def perform = record_sync(SYNC) { commit_mutations.with_import_lock { import_commits.call } }
    end
  end
end
