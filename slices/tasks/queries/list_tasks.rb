# frozen_string_literal: true

module Tasks
  module Queries
    class ListTasks
      TODAY = Blog::Types::TaskFilter["today"]

      include Deps[task_repo: "repos.task_repo"]

      def call(filter, sprint:, page:, **search)
        return task_repo.open_in_sprint_page(sprint.id, page, **search) if filter == TODAY

        task_repo.open_in_list_page(filter, page, **search)
      end
    end
  end
end
