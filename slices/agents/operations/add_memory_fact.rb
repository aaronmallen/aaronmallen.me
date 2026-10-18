# frozen_string_literal: true

module Agents
  module Operations
    class AddMemoryFact < Blog::Operation
      ADD = Blog::Types::MemoryEventOp["add"]

      include SessionWrite
      include Deps[
        contract: "contracts.memory_fact_contract",
        memory_fact_mutations: "repos.memory_fact_mutations",
        memory_file_mutations: "repos.memory_file_mutations",
        touch_session: "operations.touch_session",
      ]

      def call(memory_file_id, params)
        fields = step validate(params)
        step touch(fields)

        transaction do
          step found(memory_file_mutations.by_id_for_update(memory_file_id))
          fact = memory_fact_mutations.create(memory_file_id:, **fields.except(:session_id))
          memory_file_mutations.record(
            memory_file_id, ADD, memory_fact_id: fact.id, **fields.slice(:type, :text), **author(fields),
          )
          fact
        end
      end
    end
  end
end
