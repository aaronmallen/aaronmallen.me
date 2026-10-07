# frozen_string_literal: true

module Tasks
  module Operations
    class WakeTask < Operation
      include Deps[task_repo: "repos.task_repo", task_source_repo: "repos.task_source_repo"]

      def call(id, now: Time.now)
        task = step found(task_repo.by_id(id))
        step snoozed(task.source, now)
        task_source_repo.snooze(id, now)

        task_repo.by_id(id)
      end
    end
  end
end
