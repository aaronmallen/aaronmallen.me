# frozen_string_literal: true

module Tasks
  module Operations
    class RenameDecisionTask < Blog::Operation
      include Deps[
        task_event_mutations: "repos.task_event_mutations",
        task_mutations: "repos.task_mutations",
        task_queries: "repos.task_queries",
      ]

      def call(decision_id, title)
        task = task_queries.by_decision(decision_id)
        return Success(nil) unless task

        task_event_mutations.track(task.id, Time.now) do
          task_mutations.update(task.id, title: OpenDecisionTask.title(decision_id, title))
        end
      end
    end
  end
end
