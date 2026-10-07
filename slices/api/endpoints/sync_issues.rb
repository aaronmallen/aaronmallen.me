# frozen_string_literal: true

module API
  module Endpoints
    class SyncIssues < Endpoint
      SCHEMA = { additionalProperties: false }.freeze
      SOURCES = %w[github linear].freeze
      REPLY = Schema.object({ queued: Schema.list({ type: "string", enum: SOURCES }) }).freeze
      UNCONFIGURED = "no GitHub token or Linear key is set, so no issue sync can run"

      include Deps[queue_issue_sync: "tasks.operations.queue_issue_sync"]

      def handle
        case queue_issue_sync.call
          in Success[*sources] then Success(queued: sources)
          in Failure(:not_configured) then failed(UNCONFIGURED)
        end
      end
    end
  end
end
