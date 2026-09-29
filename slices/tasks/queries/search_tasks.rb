# frozen_string_literal: true

module Tasks
  module Queries
    class SearchTasks
      include Deps[task_repo: "repos.task_repo"]

      def call(tags:, text:) = task_repo.search(tags:, text:)
    end
  end
end
