# frozen_string_literal: true

module Agents
  module Operations
    class SearchMemory
      include Deps[memory_file_queries: "repos.memory_file_queries"]

      def call(page, text:, scope: nil, project_id: nil, task_id: nil)
        within = { project_ids: [project_id].compact, task_ids: [task_id].compact } if project_id || task_id

        memory_file_queries.searched(page, text:, scope:, within:)
      end
    end
  end
end
