# frozen_string_literal: true

module Tasks
  module Operations
    class DeleteWorkSession < Operation
      RUNNING = "running"

      include Deps[
        work_session_mutations: "repos.work_session_mutations",
        work_session_queries: "repos.work_session_queries",
      ]

      def call(task_id, id)
        session = step find(task_id, id)
        step finished(session)

        transaction do
          work_session_mutations.shift_total(task_id, -(session.ended_at - session.started_at).floor)
          work_session_mutations.delete(id)
        end
      end

      private

      def find(task_id, id)
        found(work_session_queries.find(task_id, id))
      end

      def finished(session) = session.ended_at ? Success(session) : Failure[:invalid, { ended_at: [RUNNING] }]
    end
  end
end
