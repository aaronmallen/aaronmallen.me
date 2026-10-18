# frozen_string_literal: true

module Agents
  module Operations
    class EditMemoryFact < Blog::Operation
      EDIT = Blog::Types::MemoryEventOp["edit"]

      include SessionWrite
      include Deps[
        contract: "contracts.memory_fact_contract",
        memory_fact_mutations: "repos.memory_fact_mutations",
        memory_file_mutations: "repos.memory_file_mutations",
        find_memory_fact: "operations.find_memory_fact",
        touch_session: "operations.touch_session",
      ]

      def call(memory_file_id, id, params)
        fields = step validate(params)
        step touch(fields)

        transaction do
          fact = step find_memory_fact.call(memory_file_id, id)
          step revise(fact, fields.slice(:type, :text), author(fields))
        end
      end

      private

      def revise(fact, change, by)
        return Success(fact) if fact.type == change[:type] && fact.text == change[:text]

        saved = memory_fact_mutations.update(fact.id, **change, **by.except(:session_id))
        memory_file_mutations.record(
          fact.memory_file_id, EDIT, memory_fact_id: fact.id, **change, **fact.was, **by,
        )
        Success(saved)
      end
    end
  end
end
