# frozen_string_literal: true

module Decisions
  module Operations
    class EditDecisionComment < Blog::Operation
      PHOTO_OWNER = Blog::Types::PhotoOwner["decision_comment"]

      include Deps[
        claim_photos: "media.operations.claim_photos",
        contract: "contracts.decision_comment_contract",
        decision_comment_repo: "repos.decision_comment_repo",
      ]

      def call(decision_id, id, params)
        step find(decision_id, id)
        fields = step validate(params)

        transaction do
          claim_photos.call(PHOTO_OWNER, id, fields[:body])
          decision_comment_repo.update(id, body: fields[:body])
        end
      end

      private

      def find(decision_id, id)
        found(decision_comment_repo.on_decision?(decision_id, id) && id)
      end

      def validate(params) = validated(contract.call(body: params[:body]))
    end
  end
end
