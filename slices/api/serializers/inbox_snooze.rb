# frozen_string_literal: true

module API
  module Serializers
    class InboxSnooze < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          kind: { type: "string", enum: InboxRow::KINDS },
          id: Helpers::Schema::INTEGER,
          snoozed_until: { **Helpers::Schema::STAMP, description: "when the row comes back to the top of the inbox" },
        },
      ).freeze

      schema_attributes
      stamps :snoozed_until
    end
  end
end
