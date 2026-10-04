# frozen_string_literal: true

module API
  module Endpoints
    class SnoozeAttention < Endpoint
      FINDS = true

      SCHEMA = {
        additionalProperties: false,
        properties: {
          kind: { type: "string", enum: Blog::Types::AttentionKind.values, description: "the row's kind" },
          record_id: Schema.nullable(Schema::ID).merge(
            description: "the row's record_id from list_attention; leave it out for the journal",
          ),
        },
        required: ["kind"],
      }.freeze

      REPLY = Serializers::AttentionSnooze.reference

      include Deps[snooze_attention: "activity.operations.snooze_attention"]

      def handle(kind:, record_id: nil)
        case snooze_attention.call(kind, record_id)
        in Success(snooze) then Success(serialized(Serializers::AttentionSnooze, snooze))
        in Failure(:not_found) then not_found(missing(kind, record_id))
        else failed("could not snooze the row")
        end
      end

      private

      def missing(kind, record_id)
        record_id ? "no #{kind} row on the card has the record_id #{record_id}" : "no #{kind} row is on the card"
      end
    end
  end
end
