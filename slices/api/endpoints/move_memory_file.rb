# frozen_string_literal: true

module API
  module Endpoints
    class MoveMemoryFile < MemoryEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID,
          scope: { type: "string", enum: Blog::Types::MemoryScope.values, description: "where the file loads now" },
          repo: Helpers::Schema::REPO.merge(description: "the repository of a repo file, as owner/name"),
          project_id: Memory::ID.merge(description: "the project of a project file"),
          task_id: Helpers::Schema::TASK.merge(description: "the task of a task file"),
          **Memory::AUTHOR,
        },
        required: %w[id scope agent model],
      }.freeze

      REPLY = Serializers::MemoryFile.reference

      include Deps[change_memory_scope: "agents.operations.change_memory_scope"]

      def handle(id:, **fields)
        settled(change_memory_scope.call(id, fields), id) { serialized(Serializers::MemoryFile, it) }
      end
    end
  end
end
