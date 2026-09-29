# frozen_string_literal: true

module Tasks
  module Jobs
    class SyncIssues < Blog::Job
      include Deps[
        record_issue_sync_outcome: "record.operations.record_issue_sync_outcome",
        sync_issues: "operations.sync_issues",
        task_source_repo: "repos.task_source_repo",
      ]

      sidekiq_options retry: false

      def perform
        result = task_source_repo.with_sync_lock { sync_issues.call }

        case result
        in Failure(:lock_busy) then nil
        else record_issue_sync_outcome.call(result)
        end
      end
    end
  end
end
