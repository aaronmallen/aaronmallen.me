# frozen_string_literal: true

module Tasks
  module Jobs
    class SyncLinearIssues < Blog::ScheduledJob
      PROVIDER = Blog::Types::TaskSourceProvider["linear"]
      SYNC = Blog::Types::SyncName["linear_issues"]

      include Deps[
        client: "record.linear.client",
        record_sync_outcome: "record.operations.record_sync_outcome",
        sync_issues: "operations.sync_issues",
        task_source_mutations: "repos.task_source_mutations",
      ]

      def perform
        return unless client.configured?

        result = task_source_mutations.with_sync_lock(PROVIDER) { sync_issues.call(provider: PROVIDER, client:) }

        case result
          in Failure(:lock_busy) then nil
          else record_sync_outcome.call(SYNC, result)
        end
      end
    end
  end
end
