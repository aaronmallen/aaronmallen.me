# frozen_string_literal: true

module API
  module Endpoints
    class SnoozeInboxRow < Endpoint
      FINDS = true

      SCHEMA = {
        additionalProperties: false,
        properties: {
          kind: { type: "string", enum: Serializers::InboxRow::KINDS, description: "the row's kind" },
          id: Schema::ID.merge(description: "the row's id from list_inbox"),
          snoozed_until: {
            type: "string",
            description: "a future time, as YYYY-MM-DDTHH:MM in the site's time zone or as ISO 8601",
          },
        },
        required: %w[kind id snoozed_until],
      }.freeze

      REPLY = Serializers::InboxSnooze.reference

      include Deps[snooze_inbox_row: "operations.snooze_inbox_row"]

      def handle(kind:, id:, snoozed_until:)
        case snooze_inbox_row.call(kind, id, snoozed_until)
        in Success(snooze) then Success(serialized(Serializers::InboxSnooze, snooze))
        in Failure(:invalid) then invalid(snoozed_until: ["snoozed_until is not a time"])
        in Failure(:past) then invalid(snoozed_until: ["snoozed_until must be in the future"])
        in Failure(:not_found) then not_found("no #{kind} row has the id #{id}")
        else failed("could not snooze the row")
        end
      end
    end
  end
end
