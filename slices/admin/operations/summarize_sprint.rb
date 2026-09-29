# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeSprint < Blog::Operation
      include Deps[
        current_sprint: "tasks.operations.current_sprint",
        open_tasks_in_list: "tasks.queries.open_tasks_in_list",
        tasks_in_sprint: "tasks.queries.tasks_in_sprint",
      ]

      def call(now: Time.now, pool: nil)
        sprint = step current_sprint.call(now:)

        {
          date: Blog::TimeZone.today(now),
          pool: Blog::Types::TaskPoolParam[pool],
          pools: pools,
          tasks: tasks_in_sprint.call(sprint.id),
        }
      end

      private

      def pools = Blog::Types::TaskPool.values.to_h { [it, open_tasks_in_list.call(it)] }
    end
  end
end
