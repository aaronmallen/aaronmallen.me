# frozen_string_literal: true

module API
  module Endpoints
    class SyncPeople < Endpoint
      QUEUED = "queued"
      SCHEMA = { additionalProperties: false, properties: {} }.freeze
      REPLY = Helpers::Schema.object({ status: { type: "string", enum: [QUEUED] } }).freeze
      UNAVAILABLE = true

      include Deps[queue_contact_sync: "contacts.operations.queue_contact_sync"]

      def handle
        case queue_contact_sync.call
          in Success(_) then Success(status: QUEUED)
          in Failure(:queue_unavailable) then Failure(Structs::Refusal.queue_unavailable)
        end
      end
    end
  end
end
