# frozen_string_literal: true

module Tasks
  module Operations
    class SetTaskTotal < Blog::Operation
      include Deps[
        contract: "contracts.worked_contract",
        task_repo: "repos.task_repo",
        work_session_repo: "repos.work_session_repo",
      ]

      def call(id, params, at: Time.now)
        step find(id)
        fields = step validate(params)

        transaction do
          work_session_repo.restart(id, at)
          task_repo.update(id, worked_seconds: Contracts::WorkedContract.seconds(fields))
        end
      end

      private

      def find(id) = found(task_repo.exist?(id) && id)

      def validate(params)
        validated(contract.call({ hours: params[:hours], minutes: params[:minutes] }, required: true))
      end
    end
  end
end
