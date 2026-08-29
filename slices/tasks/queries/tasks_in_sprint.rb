# frozen_string_literal: true

module Tasks
  module Queries
    class TasksInSprint
      include Deps[task_repo: "repos.task_repo"]

      def call(sprint_id) = task_repo.in_sprint(sprint_id)
    end
  end
end
