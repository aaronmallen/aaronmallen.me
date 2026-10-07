# frozen_string_literal: true

module Tasks
  module Operations
    class WakeTask < Operation
      include Deps[task_queries: "repos.task_queries", task_source_mutations: "repos.task_source_mutations"]

      def call(id, now: Time.now)
        task = step found(task_queries.by_id(id))
        step snoozed(task.source, now)
        task_source_mutations.snooze(id, now)

        task_queries.by_id(id)
      end
    end
  end
end
