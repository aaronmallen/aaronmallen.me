# frozen_string_literal: true

module Tasks
  module Operations
    class QueueIssueSync < Blog::Operation
      include Deps[github: "record.github.client", linear: "record.linear.client"]

      def call
        jobs = step configured
        jobs.map(&:perform_async)
      end

      private

      def configured
        jobs = providers.filter_map { |job, client| job if client.configured? }

        jobs.empty? ? Failure(:not_configured) : Success(jobs)
      end

      def providers = { Jobs::SyncIssues => github, Jobs::SyncLinearIssues => linear }
    end
  end
end
