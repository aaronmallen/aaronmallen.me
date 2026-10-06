# frozen_string_literal: true

module Tasks
  module Operations
    class EditWorkSession < Blog::Operation
      FUTURE = "future"
      ORDER = "order"

      include Deps[contract: "contracts.work_session_contract", work_session_repo: "repos.work_session_repo"]

      def call(task_id, id, params, now: Time.now)
        session = step find(task_id, id)
        fields = step validate(session, params)
        started_at, ended_at = step ordered(session, fields, now)

        transaction do
          work_session_repo.shift_total(task_id, change(session, started_at, ended_at))
          work_session_repo.update(id, started_at:, ended_at:)
        end
      end

      private

      def change(session, started_at, ended_at)
        length(started_at, ended_at) - length(session.started_at, session.ended_at)
      end

      def find(task_id, id)
        found(work_session_repo.find(task_id, id))
      end

      def future(time, now) = ([FUTURE] if time && time > now)

      def kept(saved, given) = Blog::TimeZone.input_value(saved) == Blog::TimeZone.input_value(given) ? saved : given

      def length(started_at, ended_at) = ended_at ? (ended_at - started_at).floor : 0

      def ordered(session, fields, now)
        started_at = kept(session.started_at, fields[:started_at])
        ended_at = session.ended_at && kept(session.ended_at, fields[:ended_at])
        errors = { started_at: future(started_at, now), ended_at: future(ended_at, now) }.compact
        return Failure[:invalid, errors] unless errors.empty?
        return Failure[:invalid, { ended_at: [ORDER] }] if ended_at && ended_at < started_at

        Success([started_at, ended_at])
      end

      def validate(session, params)
        fields = { started_at: params[:started_at], ended_at: params[:ended_at] }

        validated(contract.call(fields, running: session.ended_at.nil?))
      end
    end
  end
end
