# frozen_string_literal: true

module Tasks
  module Queries
    class TaskTimeline
      include Deps[task_timeline_repo: "repos.task_timeline_repo"]

      def call(task_id) = task_timeline_repo.for_task(task_id)
    end
  end
end
