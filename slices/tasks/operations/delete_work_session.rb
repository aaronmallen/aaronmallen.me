# frozen_string_literal: true

module Tasks
  module Operations
    class DeleteWorkSession < Blog::Operation
      RUNNING = "running"

      include Deps[
        work_session_mutations: "repos.work_session_mutations",
      ]

      def call(task_id, id)
        transaction do
          session = step find(task_id, id)
          step lock(task_id)
          step finished(session)
          work_session_mutations.shift_total(task_id, -(session.ended_at - session.started_at).floor)
          work_session_mutations.delete(id)
        end
      end

      private

      def find(task_id, id) = found(work_session_mutations.lock(task_id, id))

      def finished(session) = session.ended_at ? Success(session) : Failure[:invalid, { ended_at: [RUNNING] }]

      def lock(task_id) = found(work_session_mutations.lock_task(task_id))
    end
  end
end
