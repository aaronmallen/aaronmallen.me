# frozen_string_literal: true

module Tasks
  module Operations
    class AddTaskComment < Blog::Operation
      PHOTO_OWNER = Blog::Types::PhotoOwner["task_comment"]

      include Deps[
        claim_photos: "media.operations.claim_photos",
        contract: "contracts.task_comment_contract",
        task_comment_mutations: "repos.task_comment_mutations",
        task_queries: "repos.task_queries",
      ]

      def call(task_id, params)
        step find(task_id)
        fields = step validate(params)

        transaction do
          comment = task_comment_mutations.create(task_id:, body: fields[:body])
          claim_photos.call(PHOTO_OWNER, comment.id, comment.body)
          comment
        end
      end

      private

      def find(id) = found(task_queries.exist?(id) && id)

      def validate(params) = validated(contract.call(body: params[:body]))
    end
  end
end
