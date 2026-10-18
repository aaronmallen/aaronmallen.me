# frozen_string_literal: true

module Agents
  module Operations
    class ChangeMemoryScope < Blog::Operation
      SCOPE = Blog::Types::MemoryEventOp["scope"]
      REFUSALS = CreateMemoryFile::REFUSALS.merge(
        "memory_files_scope_path_index" => [:scope, CreateMemoryFile::TAKEN],
      ).freeze
      TARGETS = Contracts::MemoryScopeContract::TARGETS.values.to_h { [it, nil] }.freeze

      include SessionWrite
      include Deps[
        contract: "contracts.memory_scope_contract",
        memory_file_mutations: "repos.memory_file_mutations",
        memory_file_queries: "repos.memory_file_queries",
        touch_session: "operations.touch_session",
      ]

      def call(id, params)
        fields = step validate(params)
        step touch(fields)
        step constrained(memory_file_mutations, REFUSALS) { Success(transaction { move(id, fields) }) }

        memory_file_queries.by_id(id)
      end

      private

      def move(id, fields)
        file = step found(memory_file_mutations.by_id_for_update(id))
        place = { **TARGETS, **fields.except(*AUTHOR) }
        return if place.all? { |field, value| file[field] == value }

        memory_file_mutations.update(id, place)
        memory_file_mutations.record(id, SCOPE, **author(fields))
      end
    end
  end
end
