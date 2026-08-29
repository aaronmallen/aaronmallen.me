# frozen_string_literal: true

module Tasks
  module Queries
    class TaskCountsByType
      include Deps[task_type_repo: "repos.task_type_repo"]

      def call = task_type_repo.task_counts
    end
  end
end
