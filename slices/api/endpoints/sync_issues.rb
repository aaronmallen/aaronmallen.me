# frozen_string_literal: true

module API
  module Endpoints
    class SyncIssues < Endpoint
      SCHEMA = { additionalProperties: false }.freeze
      SOURCES = %w[github linear].freeze
      REPLY = Helpers::Schema.object({ queued: Helpers::Schema.list({ type: "string", enum: SOURCES }) }).freeze
      UNAVAILABLE = true
      UNCONFIGURED = "no GitHub token or Linear key is set, so no issue sync can run"

      include Deps[
        queue_issue_sync: "tasks.operations.queue_issue_sync",
        task_source_queries: "tasks.repos.task_source_queries",
      ]

      def handle
        case queue_issue_sync.call
          in Success[*sources] then Success(queued: sources)
          in Failure(:not_configured) then Failure(Structs::Refusal.unavailable(UNCONFIGURED))
          in Failure(:queue_unavailable) then Failure(Structs::Refusal.queue_unavailable)
        end
      end

      private

      def going_public(_fields) = ("a published board" if task_source_queries.synced_to_public_board?)
    end
  end
end
