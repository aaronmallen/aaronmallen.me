# frozen_string_literal: true

module Record
  module Jobs
    class ImportCommits < Blog::ScheduledJob
      include Deps[
        commit_mutations: "repos.commit_mutations",
        import_commits: "operations.import_commits",
        record_sync_outcome: "operations.record_sync_outcome",
      ]

      def perform
        result = commit_mutations.with_import_lock { import_commits.call }

        case result
          in Failure(:lock_busy) then nil
          else record_sync_outcome.call(Blog::Types::SyncName["commits"], result)
        end
      end
    end
  end
end
