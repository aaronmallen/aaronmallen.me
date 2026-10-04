# frozen_string_literal: true

module Tasks
  module Queries
    class TasksInProgress
      include Deps[task_repo: "repos.task_repo"]

      def call = task_repo.all_open.select(&:in_progress?)
    end
  end
end
