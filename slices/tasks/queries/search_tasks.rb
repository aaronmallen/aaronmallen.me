# frozen_string_literal: true

module Tasks
  module Queries
    class SearchTasks
      include Deps[task_repo: "repos.task_repo"]

      def call(tags:, text:, types:) = task_repo.search(tags:, text:, types:)
    end
  end
end
