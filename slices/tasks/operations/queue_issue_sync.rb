# frozen_string_literal: true

module Tasks
  module Operations
    class QueueIssueSync < Blog::Operation
      include Deps[client: "record.github.client"]

      def call
        step configured
        Jobs::SyncIssues.perform_async
      end

      private

      def configured = client.configured? ? Success() : Failure(:not_configured)
    end
  end
end
