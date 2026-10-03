# frozen_string_literal: true

module Tasks
  module Queries
    class LinkableTasks
      include Deps[task_repo: "repos.task_repo"]

      def matching(text, limit:) = task_repo.linkable(:tasks, text:, limit:)

      def named(ids) = task_repo.linkable(:tasks, ids:)
    end
  end
end
