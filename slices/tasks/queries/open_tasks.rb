# frozen_string_literal: true

module Tasks
  module Queries
    class OpenTasks
      TODAY = Blog::Types::TaskView["today"]
      UPCOMING = Blog::Types::TaskView["upcoming"]

      include Deps[sprint_repo: "repos.sprint_repo", task_repo: "repos.task_repo"]

      def call(now: Time.now)
        planned = sprint_repo.after(Blog::TimeZone.today(now)).map(&:id)
        found = task_repo.all_open.group_by { view(it, planned) }

        Blog::Types::TaskView.values.to_h { [it, found.fetch(it, Dry::Core::Constants::EMPTY_ARRAY)] }
      end

      private

      def view(task, planned) = task.list || (planned.include?(task.sprint_id) ? UPCOMING : TODAY)
    end
  end
end
