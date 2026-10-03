# frozen_string_literal: true

module Decisions
  module Operations
    class AddDecisionComment < Blog::Operation
      PHOTO_OWNER = Blog::Types::PhotoOwner["decision_comment"]

      include Deps[
        claim_photos: "media.operations.claim_photos",
        contract: "contracts.decision_comment_contract",
        decision_comment_repo: "repos.decision_comment_repo",
        decision_repo: "repos.decision_repo",
      ]

      def call(decision_id, params)
        step find(decision_id)
        fields = step validate(params)

        transaction do
          comment = decision_comment_repo.create(decision_id:, body: fields[:body])
          claim_photos.call(PHOTO_OWNER, comment.id, comment.body)
          comment
        end
      end

      private

      def find(id) = decision_repo.exist?(id) ? Success(id) : Failure(:not_found)

      def validate(params) = validated(contract.call(body: params[:body]))
    end
  end
end
