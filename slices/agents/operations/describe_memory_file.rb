# frozen_string_literal: true

module Agents
  module Operations
    class DescribeMemoryFile < Blog::Operation
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

      def describe(file, description:, agent:, model:, **)
        memory_file_mutations.update(file.id, { description:, description_agent: agent, description_model: model })
      end
    end
  end
end
