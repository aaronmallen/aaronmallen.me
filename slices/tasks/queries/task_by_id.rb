# frozen_string_literal: true

module Tasks
  module Queries
    class TaskById
      include Deps[task_repo: "repos.task_repo"]

      def call(id) = task_repo.detailed(id)
    end
  end
end
