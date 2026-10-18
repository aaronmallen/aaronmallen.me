# frozen_string_literal: true

module API
  module Endpoints
    class EditMemoryFact < MemoryEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Memory::ID,
          fact_id: Memory::ID,
          type: Memory::FACT_TYPE,
          text: Memory::FACT_TEXT,
          **Memory::AUTHOR,
        },
        required: %w[id fact_id agent model],
      }.freeze

      REPLY = Serializers::MemoryFact.reference

      include Deps[
        edit_memory_fact: "agents.operations.edit_memory_fact",
        memory_file_queries: "agents.repos.memory_file_queries",
      ]

      def handle(id:, fact_id:, **fields)
        fact = memory_file_queries.by_id(id)&.facts&.find { it.id == fact_id }
        return not_found(Memory.missing_fact(id, fact_id)) if fact.nil?

        result = edit_memory_fact.call(id, fact_id, { type: fact.type, text: fact.text }.merge(fields))
        settled(result, id, missing: Memory.missing_fact(id, fact_id)) { serialized(Serializers::MemoryFact, it) }
      end
    end
  end
end
