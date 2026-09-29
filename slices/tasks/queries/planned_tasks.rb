# frozen_string_literal: true

module Tasks
  module Queries
    class PlannedTasks
      include Deps[task_repo: "repos.task_repo"]

      def call(planned) = task_repo.open_in_sprint(planned.map(&:id))
    end
  end
end
