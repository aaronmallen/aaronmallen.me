# frozen_string_literal: true

module API
  module Endpoints
    class ReadMemory < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          repo: Helpers::Schema::REPO.merge(description: "load the repo's files and those of its projects"),
          project_id: Memory::ID.merge(description: "load the project's files"),
          task_id: Helpers::Schema::TASK.merge(description: "load the task's files"),
        },
      }.freeze

      MARKDOWN = "the files as an agent loads them; marked untrusted when an agent wrote any of the facts"

      REPLY = Helpers::Schema.object(
        {
          markdown: { type: "string", description: MARKDOWN },
          files: Helpers::Schema.list(Serializers::MemoryFile.reference).merge(
            description: "the files that loaded: global, then repo, project and task",
          ),
        },
      ).freeze

      include Deps[load_memory: "agents.operations.load_memory"]

      def handle(**where)
        files = load_memory.call(**where)
        markdown = files.map(&:markdown).join("\n")

        Success(
          markdown: files.any?(&:agent_written?) ? Helpers::Untrusted.call(markdown) : markdown,
          files: serialized(Serializers::MemoryFile, files),
        )
      end
    end
  end
end
