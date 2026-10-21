# frozen_string_literal: true

module Agents
  module Operations
    class DescribeMemoryFile < Blog::Operation
      DESCRIBE = Blog::Types::MemoryEventOp["describe"]

      include SessionWrite
      include Deps[
        contract: "contracts.memory_description_contract",
        memory_file_mutations: "repos.memory_file_mutations",
        memory_file_queries: "repos.memory_file_queries",
        touch_session: "operations.touch_session",
      ]

      def call(id, params)
        fields = step validate(params)
        step touch(fields)

        transaction do
          file = step found(memory_file_mutations.by_id_for_update(id))
          describe(file, **fields) unless file.description == fields[:description]
          memory_file_queries.by_id(id)
        end
      end

      private

      def describe(file, description:, **fields)
        memory_file_mutations.update(
          file.id, { description:, description_agent: fields[:agent], description_model: fields[:model] },
        )
        memory_file_mutations.record(
          file.id, DESCRIBE,
          text: description, was_text: file.description, was_agent: file.description_agent,
          was_model: file.description_model, **author(fields),
        )
      end
    end
  end
end
