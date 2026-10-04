# frozen_string_literal: true

module Tasks
  module Operations
    class StartTask < Blog::Operation
      include Deps[
        current_sprint: "operations.current_sprint",
        task_event_repo: "repos.task_event_repo",
        task_repo: "repos.task_repo",
        work_session_repo: "repos.work_session_repo",
      ]

      def call(id, at: Time.now, seen: true)
        sprint = step current_sprint.call(now: at)

        transaction do
          step find(id)
          task_event_repo.track(id, at, seen:) do
            work_session_repo.open(id, at)
            task_repo.update(
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

      def find(id) = work_session_repo.lock_task(id) ? Success(id) : Failure(:not_found)
    end
  end
end
