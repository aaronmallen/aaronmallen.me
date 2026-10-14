# frozen_string_literal: true

module Admin
  module Operations
    class SummarizeSprint < Blog::Operation
      include Blog::Constants

      include Deps[
        current_sprint: "tasks.operations.current_sprint",
        task_queries: "tasks.repos.task_queries",
      ]

      def call(page:, now: Time.now, pool: nil)
        sprint = step current_sprint.call(now:)
        pool = Blog::Types::TaskListParam[pool]

        {
          counts: task_queries.open_counts(sprint:, planned: EMPTY_ARRAY),
          date: Blog::TimeZone.today(now),
          pool:,
          pools: { pool => task_queries.list(pool, sprint: nil, page:).rows },
          tasks: task_queries.in_sprint(sprint.id),
        }
      end
    end
  end
end
