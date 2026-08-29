# frozen_string_literal: true

module Tasks
  module Queries
    class FindTasks
      include Deps[task_repo: "repos.task_repo"]

      def call(statuses:, from:, to:) = task_repo.filtered(statuses:, from:, to:)
    end
  end
end
