# frozen_string_literal: true

module Tasks
  module Jobs
    class SyncIssues < Blog::Job
      PROVIDER = Blog::Types::TaskSourceProvider["github"]

      include Deps[
        client: "record.github.client",
        record_issue_sync_outcome: "record.operations.record_issue_sync_outcome",
        sync_issues: "operations.sync_issues",
        task_source_mutations: "repos.task_source_mutations",
      ]

      sidekiq_options retry: false

      def perform
        return unless client.configured?

        result = task_source_mutations.with_sync_lock(PROVIDER) { sync_issues.call(provider: PROVIDER, client:) }

        case result
          in Failure(:lock_busy) then nil
          else record_issue_sync_outcome.call(result)
        end
      end
    end
  end
end
