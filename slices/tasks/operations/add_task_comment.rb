# frozen_string_literal: true

module Tasks
  module Operations
    class AddTaskComment < Blog::Operation
      include Deps[
        contract: "contracts.task_comment_contract",
        task_comment_repo: "repos.task_comment_repo",
        task_repo: "repos.task_repo",
      ]

      def call(task_id, params)
        step find(task_id)
        fields = step validate(params)

        task_comment_repo.create(task_id:, body: fields[:body])
      end

      private

      def find(id) = task_repo.exist?(id) ? Success(id) : Failure(:not_found)

      def validate(params) = validated(contract.call(body: params[:body]))
    end
  end
end
