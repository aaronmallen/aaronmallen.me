# frozen_string_literal: true

module Tasks
  module Jobs
    class SyncIssues < Blog::ScheduledJob
      SYNCS = { "github" => Blog::Types::SyncName["issues"], "linear" => Blog::Types::SyncName["linear_issues"] }.freeze

      include Deps[
        github: "github.client",
        linear: "linear.client",
        record_sync_outcome: "record.operations.record_sync_outcome", # rubocop:disable Hanami/UnusedDeps
        sync_issues: "operations.sync_issues",
        task_source_mutations: "repos.task_source_mutations",
      ]

      def perform(provider)
        provider = Blog::Types::TaskSourceProvider[provider]
        client = { "github" => github, "linear" => linear }.fetch(provider)
        return unless client.configured?

        result = record_crash(SYNCS.fetch(provider)) do
          task_source_mutations.with_sync_lock(provider) { sync_issues.call(provider:, client:) }
        end

        record_outcome(SYNCS.fetch(provider), result)
      end
    end
  end
end
