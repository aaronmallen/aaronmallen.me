# frozen_string_literal: true

module Agents
  module Operations
    class SearchMemory
      include Deps[memory_file_queries: "repos.memory_file_queries", project_queries: "projects.repos.project_queries"]

      def call(page, text:, scope: nil, repo: nil, project_id: nil, task_id: nil)
        within = loading(repo, project_id, task_id) if repo || project_id || task_id

        memory_file_queries.searched(page, text:, scope:, within:)
      end

      private

      def loading(repo, project_id, task_id)
        { repo:, project_ids: [project_id, *(project_queries.ids_by_repo(repo) if repo)].compact,
          task_ids: [task_id].compact }
      end
    end
  end
end
