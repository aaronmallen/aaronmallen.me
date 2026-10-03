# frozen_string_literal: true

module Tasks
  module Queries
    class UnseenTasks
      include Deps[task_source_repo: "repos.task_source_repo"]

      def call = task_source_repo.unseen_tasks
    end
  end
end
