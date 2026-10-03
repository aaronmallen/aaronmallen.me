# frozen_string_literal: true

module Tasks
  module Operations
    class ReopenTask < Blog::Operation
      include Deps[task_repo: "repos.task_repo", work_session_repo: "repos.work_session_repo"]

      def call(id, at: Time.now)
        step find(id)

        transaction do
          work_session_repo.close(id, at)
          task_repo.update(id, completed_at: nil, status: Blog::Types::TaskStatus["open"])
        end
      end

      private

      def find(id) = task_repo.by_id(id) ? Success(id) : Failure(:not_found)
    end
  end
end
