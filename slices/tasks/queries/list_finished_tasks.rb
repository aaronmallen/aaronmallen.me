# frozen_string_literal: true

module Tasks
  module Queries
    class ListFinishedTasks
      include Deps[task_repo: "repos.task_repo"]

      def call(page:, **search) = task_repo.finished(page, **search)
    end
  end
end
