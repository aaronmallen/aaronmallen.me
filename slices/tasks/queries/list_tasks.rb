# frozen_string_literal: true

module Tasks
  module Queries
    class ListTasks
      TODAY = Blog::Types::TaskView["today"]
      UPCOMING = Blog::Types::TaskView["upcoming"]

      include Deps[sprint_repo: "repos.sprint_repo", task_repo: "repos.task_repo"]

      def call(sprint:)
        planned = sprint_repo.after(sprint.sprint_date).map(&:id)

        Blog::Types::TaskView.values.to_h { [it, listed(it, sprint, planned)] }
      end

      private

      def listed(view, sprint, planned)
        case view
        when TODAY then task_repo.in_sprint(sprint.id)
        when UPCOMING then task_repo.in_sprint(planned)
        else task_repo.in_list(view)
        end
      end
    end
  end
end
