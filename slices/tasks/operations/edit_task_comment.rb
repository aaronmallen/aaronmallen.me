# frozen_string_literal: true

module Tasks
  module Operations
    class EditTaskComment < Blog::Operation
      PHOTO_OWNER = Blog::Types::PhotoOwner["task_comment"]

      include Deps[
        claim_photos: "media.operations.claim_photos",
        contract: "contracts.task_comment_contract",
        task_comment_repo: "repos.task_comment_repo",
      ]

      def call(task_id, id, params)
        step find(task_id, id)
        fields = step validate(params)

        transaction do
          claim_photos.call(PHOTO_OWNER, id, fields[:body])
          task_comment_repo.update(id, body: fields[:body])
        end
      end

      private

      def find(task_id, id) = task_comment_repo.local?(task_id, id) ? Success(id) : Failure(:not_found)

      def validate(params) = validated(contract.call(body: params[:body]))
    end
  end
end
