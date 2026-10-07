# frozen_string_literal: true

module Tasks
  module Operations
    class CancelTask < Operation
      include Deps[
        task_event_repo: "repos.task_event_repo",
        task_repo: "repos.task_repo",
        work_session_repo: "repos.work_session_repo",
      ]

      def call(id, at: Time.now)
        step find(id)

        task_event_repo.track(id, at) do
          work_session_repo.close(id, at)
          task_repo.cancel(id, at:)
        end
      end

      private

      def find(id)
        found(task_repo.by_id(id)).bind { it.closed? ? Failure(:closed) : Success(it) }
      end
    end
  end
end
