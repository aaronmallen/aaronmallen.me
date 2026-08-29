# frozen_string_literal: true

module Tasks
  module Queries
    class OpenTasksInList
      include Deps[task_repo: "repos.task_repo"]

      def call(list) = task_repo.open_in_list(list)
    end
  end
end
