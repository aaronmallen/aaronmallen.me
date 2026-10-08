# frozen_string_literal: true

module API
  module Serializers
    class AttentionSnooze < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          kind: { type: "string", enum: Blog::Types::AttentionKind.values },
          record_id: Helpers::Schema.nullable(Helpers::Schema::INTEGER),
          ends_at: {
            **Helpers::Schema::STAMP,
            description: "when the row comes back to the card if it is still stalled",
          },
        },
      ).freeze

      schema_attributes
      stamps :ends_at
    end
  end
end
