# frozen_string_literal: true

module API
  module Serializers
    class AttentionSnooze < Serializer
      SCHEMA = Schema.object(
        {
          kind: { type: "string", enum: Blog::Types::AttentionKind.values },
          record_id: Schema.nullable(Schema::INTEGER),
          ends_at: { **Schema::STAMP, description: "when the row comes back to the card if it is still stalled" },
        },
      ).freeze

      attributes :kind, :record_id, :ends_at

      def ends_at(snooze) = stamp(snooze.ends_at)
    end
  end
end
