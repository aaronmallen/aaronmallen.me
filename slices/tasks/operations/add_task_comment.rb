# frozen_string_literal: true

module Tasks
  module Operations
    class AddTaskComment < Operation
      PHOTO_OWNER = Blog::Types::PhotoOwner["task_comment"]

      include Deps[
        claim_photos: "media.operations.claim_photos",
        contract: "contracts.task_comment_contract",
        task_comment_repo: "repos.task_comment_repo",
        task_repo: "repos.task_repo",
      ]

      def call(task_id, params)
        step find(task_id)
        fields = step validate(params)

        transaction do
          comment = task_comment_repo.create(task_id:, body: fields[:body])
          claim_photos.call(PHOTO_OWNER, comment.id, comment.body)
          comment
        end
      end

      private

      def find(id) = found(task_repo.exist?(id) && id)

      def validate(params) = validated(contract.call(body: params[:body]))
    end
  end
end
