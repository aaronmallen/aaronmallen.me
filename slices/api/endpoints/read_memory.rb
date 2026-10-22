# frozen_string_literal: true

module API
  module Endpoints
    class ReadMemory < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          project: Memory::PROJECT,
          repo: Memory::REPO,
          project_id: Memory::ID.merge(description: "list the project's files"),
          task_id: Helpers::Schema::TASK.merge(description: "list the task's files"),
        },
      }.freeze

      REPLY = Helpers::Schema.object(Memory::LOADED).freeze

      MALFORMED = { repo: [Blog::Contract::FORMAT] }.freeze

      include Deps[load_memory: "agents.operations.load_memory", resolve_project: "agents.operations.resolve_project"]

      def handle(task_id: nil, project_id: nil, project: nil, repo: nil)
        repo = Blog::Types::OptionalText[repo]
        repo &&= Blog::Types::Normalized::Repo.call(repo) { return rejected(MALFORMED, Memory::COMPLAINTS) }

        project = Blog::Types::OptionalText[project]
        case resolve_project.call(project:, repo:)
          in Success(id) then Success(Memory.loaded(load(project_id || id, task_id)))
          in Failure[:invalid, errors] then rejected(errors, Memory::COMPLAINTS)
          in unmatched then unhandled(unmatched, Helpers::Wording::UNSAVED)
        end
      end

      private

      def load(project_id, task_id) = load_memory.call(project_id:, task_ids: [task_id].compact)
    end
  end
end
