# frozen_string_literal: true

module Tasks
  module Operations
    class OpenDecisionTask < Blog::Operation
      include Deps[
        capture_task: "operations.capture_task",
        task_mutations: "repos.task_mutations",
      ]

      def call(decision_id, title)
        transaction do
          _, task = step capture_task.call({ title: "Resolve decision ##{decision_id}: #{title}", note: "", tags: "" })
          task_mutations.source_from_decision(task.id, decision_id)
          task
        end
      end
    end
  end
end
