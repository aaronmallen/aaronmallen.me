# frozen_string_literal: true

module Tasks
  module Operations
    class AddWorkSession < Blog::Operation
      include Deps[
        check_session_times: "operations.check_session_times",
        contract: "contracts.work_session_contract",
        work_session_mutations: "repos.work_session_mutations",
      ]

      def call(task_id, params, now: Time.now)
        transaction do
          step found(work_session_mutations.lock_task(task_id))
          started_at, ended_at = step times(params, now)
          work_session_mutations.shift_total(task_id, length(started_at, ended_at))
          work_session_mutations.create(task_id:, started_at:, ended_at:)
        end
      end

      private

      def length(started_at, ended_at) = (ended_at - started_at).floor

      def times(params, now)
        validated(contract.call({ started_at: params[:started_at], ended_at: params[:ended_at] }))
          .bind { check_session_times.call(it[:started_at], it[:ended_at], now) }
      end
    end
  end
end
