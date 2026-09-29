# frozen_string_literal: true

module Tasks
  module Queries
    class ListTasks
      TODAY = Blog::Types::TaskFilter["today"]

      include Deps[task_repo: "repos.task_repo"]

      def call(filter, sprint:, page:)
        filter == TODAY ? task_repo.open_in_sprint_page(sprint.id, page) : task_repo.open_in_list_page(filter, page)
      end
    end
  end
end
