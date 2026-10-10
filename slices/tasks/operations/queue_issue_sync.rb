# frozen_string_literal: true

module Tasks
  module Operations
    class QueueIssueSync < Blog::Operation
      JOBS = { "github" => Jobs::SyncIssues, "linear" => Jobs::SyncLinearIssues }.freeze

      include Deps[github: "record.github.client", linear: "record.linear.client"]

      def call
        sources = step configured
        sources.each { |source| JOBS.fetch(source).perform_async }
      end

      private

      def clients = { "github" => github, "linear" => linear }

      def configured
        sources = clients.filter_map { |source, client| source if client.configured? }

        sources.empty? ? Failure(:not_configured) : Success(sources)
      end
    end
  end
end
