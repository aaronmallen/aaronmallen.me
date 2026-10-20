# frozen_string_literal: true

module Agents
  module Operations
    class CreateMemoryFile < Blog::Operation
      CREATE = Blog::Types::MemoryEventOp["create"]
      TAKEN = "taken"
      REFUSALS = {
        "memory_files_scope_path_index" => [:path, TAKEN],
        "memory_files_project_id_fkey" => [:project_id, Blog::Contract::MISSING],
        "memory_files_task_id_fkey" => [:task_id, Blog::Contract::MISSING],
      }.freeze

      include SessionWrite
      include Deps[
        contract: "contracts.memory_file_contract",
        memory_file_mutations: "repos.memory_file_mutations",
        memory_file_queries: "repos.memory_file_queries",
        touch_session: "operations.touch_session",
      ]

      def call(params)
        fields = step validate(params)
        step touch(fields)
        id = step constrained(memory_file_mutations, REFUSALS) { Success(transaction { create(fields) }) }

        memory_file_queries.by_id(id)
      end

      private

      def create(fields)
        file = memory_file_mutations.create(
          **fields.except(*AUTHOR), description_agent: fields[:agent], description_model: fields[:model],
        )
        memory_file_mutations.record(file.id, CREATE, **author(fields))
        file.id
      end
    end
  end
end
