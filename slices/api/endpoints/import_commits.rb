# frozen_string_literal: true

module API
  module Endpoints
    class ImportCommits < Endpoint
      QUEUED = "queued"
      SCHEMA = { additionalProperties: false, properties: {} }.freeze
      REPLY = Helpers::Schema.object({ status: { type: "string", enum: [QUEUED] } }).freeze
      UNAVAILABLE = true

      include Deps[queue_commit_import: "record.operations.queue_commit_import"]

      def handle
        case queue_commit_import.call
          in Success(_) then Success(status: QUEUED)
          in Failure(:not_configured)
            Failure(Structs::Refusal.unavailable("GitHub isn't connected, so no import can run"))
          in Failure(:queue_unavailable) then Failure(Structs::Refusal.queue_unavailable)
        end
      end
    end
  end
end
