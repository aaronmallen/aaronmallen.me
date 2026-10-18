# frozen_string_literal: true

module Agents
  module Operations
    class CreateMemoryFile < Blog::Operation
      CREATE = Blog::Types::MemoryEventOp["create"]
      REFUSALS = {
        "memory_files_scope_path_index" => [:path, "taken"],
        "memory_files_project_id_fkey" => [:project_id, Blog::Contract::MISSING],
        "memory_files_task_id_fkey" => [:task_id, Blog::Contract::MISSING],
      }.freeze

      include SessionWrite
      include Deps[
        contract: "contracts.memory_file_contract",
        memory_file_mutations: "repos.memory_file_mutations",
        memory_file_queries: "repos.memory_file_queries",
      ]

      def call(params)
        fields = step validate(params)
        id = step constrained(memory_file_mutations, REFUSALS) { Success(transaction { create(**fields) }) }

        memory_file_queries.by_id(id)
      end

      private

      def create(agent: nil, model: nil, session_id: nil, **fields)
        file = memory_file_mutations.create(**fields)
        memory_file_mutations.record(file.id, CREATE, agent:, model:, session_id:)
        file.id
      end
    end
  end
end
