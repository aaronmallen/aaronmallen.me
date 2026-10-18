# frozen_string_literal: true

module API
  module Endpoints
    class RemoveMemoryFact < MemoryEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Memory::ID, fact_id: Memory::ID, **Memory::AUTHOR },
        required: %w[id fact_id agent model],
      }.freeze

      REPLY = Serializers::MemoryEvent.reference

      include Deps[remove_memory_fact: "agents.operations.remove_memory_fact"]

      def handle(id:, fact_id:, **author)
        result = remove_memory_fact.call(id, fact_id, author)
        settled(result, id, missing: Memory.missing_fact(id, fact_id)) { serialized(Serializers::MemoryEvent, it) }
      end
    end
  end
end
