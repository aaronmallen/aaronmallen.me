# frozen_string_literal: true

module Agents
  module Operations
    class LoadMemory
      include Deps[memory_file_queries: "repos.memory_file_queries", project_queries: "projects.repos.project_queries"]

      def call(repo: nil, project_id: nil, task_id: nil)
        project_ids = [project_id, *(project_queries.ids_by_repo(repo) if repo)].compact

        memory_file_queries.loaded(repo:, project_ids:, task_ids: [task_id].compact)
      end
    end
  end
end
