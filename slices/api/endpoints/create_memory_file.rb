# frozen_string_literal: true

module API
  module Endpoints
    class CreateMemoryFile < MemoryEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          path: { type: "string", description: "such as hanami or rails/testing; .md is added when it is missing" },
          scope: { type: "string", enum: Blog::Types::MemoryScope.values },
          repo: Helpers::Schema::REPO.merge(description: "the repository of a repo file, as owner/name"),
          project_id: Memory::ID.merge(description: "the project of a project file"),
          task_id: Helpers::Schema::TASK.merge(description: "the task of a task file"),
          **Memory::AUTHOR,
        },
        required: %w[path scope],
      }.freeze

      REPLY = Serializers::MemoryFile.reference

      include Deps[create_memory_file: "agents.operations.create_memory_file"]

      def handle(**fields)
        settled(create_memory_file.call(fields), nil) { serialized(Serializers::MemoryFile, it) }
      end
    end
  end
end
