# frozen_string_literal: true

module API
  module Serializers
    class MemoryFact < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          type: { type: "string", enum: Blog::Types::MemoryFactType.values },
          text: { type: "string", description: "the fact; marked untrusted when an agent wrote it" },
          agent: Helpers::Schema.nullable({ type: "string",
                                            description: "the agent that last wrote it; null for the owner" }),
          model: Helpers::Schema.nullable({ type: "string",
                                            description: "the model that last wrote it; null for the owner" }),
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at

      def text(fact) = fact.agent? ? untrusted(fact.text) : fact.text
    end
  end
end
