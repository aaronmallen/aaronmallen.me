# frozen_string_literal: true

module Tasks
  module Operations
    class MoveTask < Blog::Operation
      TODAY = Blog::Types::TaskFilter["today"]

      include Deps[
        current_sprint: "operations.current_sprint",
        task_event_mutations: "repos.task_event_mutations",
        task_mutations: "repos.task_mutations",
        task_queries: "repos.task_queries",
      ]

      def call(id, filter, at: Time.now)
        step find(id)
        sprint = step current_sprint.call(now: at) if filter == TODAY

        task_event_mutations.track(id, at) do
          next task_mutations.join_sprint(id, sprint.id) if sprint

          task_mutations.move_to_list(id, Blog::Types::TaskList[filter], at:)
        end
      end

      private

      def find(id) = found(task_queries.by_id(id) && id)
    end
  end
end
