# frozen_string_literal: true

module Tasks
  module Queries
    class TaskComments
      include Deps[task_comment_repo: "repos.task_comment_repo"]

      def call(task_id) = task_comment_repo.for_task(task_id)
    end
  end
end
