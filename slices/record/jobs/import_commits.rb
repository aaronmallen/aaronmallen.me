# frozen_string_literal: true

module Record
  module Jobs
    class ImportCommits < Blog::Job
      include Deps[
        commit_repo: "repos.commit_repo",
        import_commits: "operations.import_commits",
        record_sync_outcome: "operations.record_sync_outcome",
      ]

      sidekiq_options retry: false

      def perform
        result = commit_repo.with_import_lock { import_commits.call }

        case result
        in Failure(:lock_busy) then nil
        else record_sync_outcome.call(Blog::Types::SyncName["commits"], result)
        end
      end
    end
  end
end
