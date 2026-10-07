# frozen_string_literal: true

module Tasks
  module Operations
    class StartTask < Operation
      include Deps[
        current_sprint: "operations.current_sprint",
        task_event_mutations: "repos.task_event_mutations",
        task_mutations: "repos.task_mutations",
        work_session_mutations: "repos.work_session_mutations",
      ]

      def call(id, at: Time.now, seen: true)
        sprint = step current_sprint.call(now: at)

        transaction do
          step find(id)
          task_event_mutations.track(id, at, seen:) do
            work_session_mutations.open(id, at)
            task_mutations.update(
              id,
              completed_at: nil,
              list: nil,
              sprint_id: sprint.id,
              status: Blog::Types::TaskStatus["in_progress"],
            )
          end
        end
      end

      private

      def find(id) = found(work_session_mutations.lock_task(id) && id)
    end
  end
end
