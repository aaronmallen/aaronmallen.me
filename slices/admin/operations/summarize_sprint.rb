# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeSprint < Operation
      include Deps[
        current_sprint: "tasks.operations.current_sprint",
        task_queries: "tasks.repos.task_queries",
      ]

      def call(now: Time.now, pool: nil)
        sprint = step current_sprint.call(now:)
        pools = self.pools

        {
          counts: pools.transform_values(&:size),
          date: Blog::TimeZone.today(now),
          pool: Blog::Types::TaskListParam[pool],
          pools:,
          tasks: task_queries.in_sprint(sprint.id),
        }
      end

      private

      def pools = Blog::Types::TaskList.values.to_h { [it, task_queries.open_in_list(it)] }
    end
  end
end
