# frozen_string_literal: true

module API
  module Endpoints
    class WakeInboxRow < Endpoint
      FINDS = true
      NOT_SNOOZED = "%s %s is not snoozed"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          kind: { type: "string", enum: Serializers::InboxRow::KINDS, description: "the row's kind" },
          id: Helpers::Schema::ID.merge(description: "the id of the message, webmention or task"),
        },
        required: %w[kind id],
      }.freeze

      REPLY = Serializers::InboxRow.reference

      include Deps["operations.wake_inbox_row"]

      def handle(kind:, id:)
        case wake_inbox_row.call(kind, id)
          in Success(row) then Success(serialized(Serializers::InboxRow, row))
          in Failure(:not_found) then not_found(Helpers::Wording.missing(kind, id))
          in Failure(:not_snoozed) then invalid(id: [format(NOT_SNOOZED, kind, id)])
        end
      end
    end
  end
end
