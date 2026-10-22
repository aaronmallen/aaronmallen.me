# frozen_string_literal: true

module Agents
  module Operations
    class LoadMemory
      include Deps[memory_file_queries: "repos.memory_file_queries"]

      def call(project_id: nil, task_ids: [])
        memory_file_queries.loaded(project_ids: [project_id].compact, task_ids:)
      end
    end
  end
end
