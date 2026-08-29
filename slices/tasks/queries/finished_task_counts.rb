# frozen_string_literal: true

module Tasks
  module Queries
    class FinishedTaskCounts
      include Deps[task_repo: "repos.task_repo"]

      def call(day) = task_repo.finished_counts(day)
    end
  end
end
