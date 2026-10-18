# frozen_string_literal: true

module API
  module Endpoints
    class AddMemoryFact < MemoryEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Memory::ID.merge(description: "the memory file to add it to"),
          type: Memory::FACT_TYPE,
          text: Memory::FACT_TEXT,
          **Memory::AUTHOR,
        },
        required: %w[id type text agent model],
      }.freeze

      REPLY = Serializers::MemoryFact.reference

      include Deps[add_memory_fact: "agents.operations.add_memory_fact"]

      def handle(id:, **fields)
        settled(add_memory_fact.call(id, fields), id) { serialized(Serializers::MemoryFact, it) }
      end
    end
  end
end
