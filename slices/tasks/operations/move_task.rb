# frozen_string_literal: true

module Tasks
  module Operations
    class MoveTask < Blog::Operation
      TODAY = Blog::Types::TaskFilter["today"]

      include Deps[
        current_sprint: "operations.current_sprint",
        task_event_repo: "repos.task_event_repo",
        task_repo: "repos.task_repo",
      ]

      def call(id, filter, at: Time.now)
        step find(id)
        sprint = step current_sprint.call(now: at) if filter == TODAY

        task_event_repo.track(id, at) do
          next task_repo.join_sprint(id, sprint.id) if sprint

          task_repo.move_to_list(id, Blog::Types::TaskList[filter], at:)
        end
      end

      private

      def find(id) = task_repo.by_id(id) ? Success(id) : Failure(:not_found)
    end
  end
end
