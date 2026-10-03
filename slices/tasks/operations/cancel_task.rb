# frozen_string_literal: true

module Tasks
  module Operations
    class CancelTask < Blog::Operation
      include Deps[task_repo: "repos.task_repo", work_session_repo: "repos.work_session_repo"]

      def call(id, at: Time.now)
        step find(id)

        transaction do
          work_session_repo.close(id, at)
          task_repo.cancel(id, at:)
        end
      end

      private

      def find(id)
        task = task_repo.by_id(id)
        return Failure(:not_found) unless task

        task.closed? ? Failure(:closed) : Success(task)
      end
    end
  end
end
