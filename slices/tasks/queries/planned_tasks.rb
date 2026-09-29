# frozen_string_literal: true

module Tasks
  module Queries
    class PlannedTasks
      include Deps[task_repo: "repos.task_repo"]

      def call(planned, **search) = task_repo.open_in_sprint(planned.map(&:id), **search)
    end
  end
end
