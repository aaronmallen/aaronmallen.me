# frozen_string_literal: true

module Tasks
  module Operations
    class DeleteWorkSession < Blog::Operation
      include Deps[work_session_repo: "repos.work_session_repo"]

      def call(task_id, id)
        session = step find(task_id, id)

        transaction do
          work_session_repo.shift_total(task_id, -(session.ended_at - session.started_at).floor) if session.ended_at
          work_session_repo.delete(id)
        end
      end

      private

      def find(task_id, id)
        session = work_session_repo.find(task_id, id)

        session ? Success(session) : Failure(:not_found)
      end
    end
  end
end
