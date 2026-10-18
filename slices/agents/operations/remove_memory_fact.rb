# frozen_string_literal: true

module Agents
  module Operations
    class RemoveMemoryFact < Blog::Operation
      REMOVE = Blog::Types::MemoryEventOp["remove"]

      include SessionWrite
      include Deps[
        contract: "contracts.author_contract",
        find_memory_fact: "operations.find_memory_fact",
        memory_fact_mutations: "repos.memory_fact_mutations",
        memory_file_mutations: "repos.memory_file_mutations",
      ]

      def call(memory_file_id, id, params, at: Time.now)
        author = step validate(params)

        transaction do
          fact = step find_memory_fact.call(memory_file_id, id)
          memory_fact_mutations.update(fact.id, removed_at: at)
          memory_file_mutations.record(
            memory_file_id, REMOVE, memory_fact_id: fact.id, **fact.was, **author,
          )
        end
      end
    end
  end
end
