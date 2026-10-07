# frozen_string_literal: true

module Tasks
  module Operations
    class SetTaskTotal < Operation
      include Deps[
        contract: "contracts.worked_contract",
        task_mutations: "repos.task_mutations",
        task_queries: "repos.task_queries",
        work_session_mutations: "repos.work_session_mutations",
      ]

      def call(id, params, at: Time.now)
        step find(id)
        fields = step validate(params)

        transaction do
          work_session_mutations.restart(id, at)
          task_mutations.update(id, worked_seconds: Contracts::WorkedContract.seconds(fields))
        end
      end

      private

      def find(id) = found(task_queries.exist?(id) && id)

      def validate(params)
        validated(contract.call({ hours: params[:hours], minutes: params[:minutes] }, required: true))
      end
    end
  end
end
