# frozen_string_literal: true

module Tasks
  module Operations
    class EditWorkSession < Blog::Operation
      include Deps[
        check_session_times: "operations.check_session_times",
        contract: "contracts.work_session_contract",
        work_session_mutations: "repos.work_session_mutations",
      ]

      def call(task_id, id, params, now: Time.now)
        transaction do
          session = step find(task_id, id)
          step lock(task_id)
          fields = step validate(session, params)
          started_at, ended_at = step ordered(session, fields, now)
          work_session_mutations.shift_total(task_id, change(session, started_at, ended_at))
          work_session_mutations.update(id, started_at:, ended_at:)
        end
      end

      private

      def change(session, started_at, ended_at)
        length(started_at, ended_at) - length(session.started_at, session.ended_at)
      end

      def find(task_id, id) = found(work_session_mutations.lock(task_id, id))

      def kept(saved, given) = Blog::TimeZone.input_value(saved) == Blog::TimeZone.input_value(given) ? saved : given

      def length(started_at, ended_at) = ended_at ? (ended_at - started_at).floor : 0

      def lock(task_id) = found(work_session_mutations.lock_task(task_id))

      def ordered(session, fields, now)
        started_at = kept(session.started_at, fields[:started_at])
        ended_at = session.ended_at && kept(session.ended_at, fields[:ended_at])
        check_session_times.call(started_at, ended_at, now)
      end

      def validate(session, params)
        fields = { started_at: params[:started_at], ended_at: params[:ended_at] }

        validated(contract.call(fields, running: session.ended_at.nil?))
      end
    end
  end
end
