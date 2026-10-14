# frozen_string_literal: true

module Tasks
  module Operations
    class ReopenDecisionTask < Blog::Operation
      include Deps[
        open_decision_task: "operations.open_decision_task",
        reopen_task: "operations.reopen_task",
        task_queries: "repos.task_queries",
      ]

      def call(decision_id, title)
        task = task_queries.by_decision(decision_id)
        return open_decision_task.call(decision_id, title) unless task

        task.closed? ? reopen_task.call(task.id) : Success(task)
      end
    end
  end
end
