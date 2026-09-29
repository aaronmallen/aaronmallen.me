# frozen_string_literal: true

module Tasks
  module Queries
    class OpenTaskCounts
      include Deps[task_repo: "repos.task_repo"]

      def call(sprint:, planned:) = task_repo.open_counts(sprint.id, planned.map(&:id))
    end
  end
end
