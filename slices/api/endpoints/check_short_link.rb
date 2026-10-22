# frozen_string_literal: true

module API
  module Endpoints
    class CheckShortLink < Endpoint
      QUEUED = "queued"
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object(
        { id: Helpers::Schema::INTEGER, status: { type: "string", enum: [QUEUED] } },
      ).freeze
      UNAVAILABLE = true

      include Deps[queue_short_link_check: "shares.operations.queue_short_link_check"]

      def handle(id:)
        case queue_short_link_check.call(id)
          in Success(_) then Success(id:, status: QUEUED)
          in Failure(:not_found) then missing("short link", id)
          in Failure(:queue_unavailable) then Failure(Structs::Refusal.queue_unavailable)
        end
      end
    end
  end
end
