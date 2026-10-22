# frozen_string_literal: true

module API
  module Endpoints
    class RunLinkCheck < Endpoint
      QUEUED = "queued"
      SCHEMA = { additionalProperties: false, properties: {} }.freeze
      REPLY = Helpers::Schema.object({ status: { type: "string", enum: [QUEUED] } }).freeze
      UNAVAILABLE = true

      include Deps[queue_link_check_run: "posts.operations.queue_link_check_run"]

      def handle
        case queue_link_check_run.call
          in Success(_) then Success(status: QUEUED)
          in Failure(:queue_unavailable) then Failure(Structs::Refusal.queue_unavailable)
        end
      end
    end
  end
end
