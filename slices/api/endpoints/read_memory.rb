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

      REPLY = Helpers::Schema.object(Memory::LOADED).freeze

      MALFORMED = { repo: [Blog::Contract::FORMAT] }.freeze

      include Deps[load_memory: "agents.operations.load_memory"]

      def handle(task_id: nil, repo: nil, **where)
        repo = Blog::Types::OptionalText[repo]
        repo &&= Blog::Types::Normalized::Repo.call(repo) { return rejected(MALFORMED, Memory::COMPLAINTS) }

        Success(Memory.loaded(load_memory.call(repo:, task_ids: [task_id].compact, **where)))
      end
    end
  end
end
