# frozen_string_literal: true

module Tasks
  module Operations
    class PauseTask < Blog::Operation
      include Deps[
        task_event_repo: "repos.task_event_repo",
        task_repo: "repos.task_repo",
        work_session_repo: "repos.work_session_repo",
      ]

      def call(id, at: Time.now)
        step find(id)

        task_event_repo.track(id, at) do
          work_session_repo.close(id, at)
          task_repo.update(id, status: Blog::Types::TaskStatus["open"])
        end
      end

      private

      def find(id)
        found(task_repo.by_id(id)).bind { it.in_progress? ? Success(it) : Failure(:idle) }
      end
    end
  end
end
