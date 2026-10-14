# frozen_string_literal: true

module Tasks
  module Operations
    class CloseDecisionTask < Blog::Operation
      include Deps[
        cancel_task: "operations.cancel_task",
        complete_task: "operations.complete_task",
        task_queries: "repos.task_queries",
      ]

      def call(decision_id, canceled: false)
        task = task_queries.by_decision(decision_id)
        return Success(task) if task.nil? || task.closed?

        canceled ? cancel_task.call(task.id) : complete_task.call(task.id)
      end
    end
  end
end
