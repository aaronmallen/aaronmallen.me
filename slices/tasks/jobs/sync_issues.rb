# frozen_string_literal: true

module Tasks
  module Jobs
    class SyncIssues < Blog::ScheduledJob
      SYNCS = { "github" => Blog::Types::SyncName["issues"], "linear" => Blog::Types::SyncName["linear_issues"] }.freeze

      include Deps[
        github: "record.github.client",
        linear: "record.linear.client",
        record_sync_outcome: "record.operations.record_sync_outcome",
        sync_issues: "operations.sync_issues",
        task_source_mutations: "repos.task_source_mutations",
      ]

      def perform(provider)
        provider = Blog::Types::TaskSourceProvider[provider]
        client = { "github" => github, "linear" => linear }.fetch(provider)
        return unless client.configured?

        result = task_source_mutations.with_sync_lock(provider) { sync_issues.call(provider:, client:) }

        case result
          in Failure(:lock_busy) then nil
          else record_sync_outcome.call(SYNCS.fetch(provider), result)
        end
      end
    end
  end
end
