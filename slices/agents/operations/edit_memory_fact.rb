# frozen_string_literal: true

module Agents
  module Operations
    class EditMemoryFact < Blog::Operation
      EDIT = Blog::Types::MemoryEventOp["edit"]

      include Deps[
        contract: "contracts.memory_fact_contract",
        memory_fact_mutations: "repos.memory_fact_mutations",
        memory_file_mutations: "repos.memory_file_mutations",
        find_memory_fact: "operations.find_memory_fact",
      ]

      def call(memory_file_id, id, params)
        fields = step validate(params)

        transaction do
          fact = step find_memory_fact.call(memory_file_id, id)
          step revise(fact, **fields)
        end
      end

      private

      def revise(fact, type:, text:, agent:, model:)
        return Success(fact) if fact.type == type && fact.text == text

        saved = memory_fact_mutations.update(fact.id, type:, text:, agent:, model:)
        memory_file_mutations.record(
          fact.memory_file_id, EDIT,
          memory_fact_id: fact.id, type:, text:, was_type: fact.type, was_text: fact.text, agent:, model:,
        )
        Success(saved)
      end
    end
  end
end
