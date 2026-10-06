# frozen_string_literal: true

module API
  module Serializers
    class Account < Serializer
      SCHEMA = Schema.object(
        {
          handle: { type: "string", description: "the handle to save as the person's handle on the network" },
          name: { type: "string", description: "the name the account shows, empty when it has none" },
          avatar: Schema.nullable({ type: "string", description: "the address of the account's picture" }),
        },
      ).freeze

      schema_attributes
    end
  end
end
