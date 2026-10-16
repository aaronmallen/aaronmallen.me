# frozen_string_literal: true

module Decisions
  module Operations
    class AddDecisionComment < Blog::AddCommentOperation
      PHOTO_OWNER = Blog::Types::PhotoOwner["decision_comment"]
      OWNER_KEY = :decision_id

      include Deps[
        comment_mutations: "repos.decision_comment_mutations",
        comment_owners: "repos.decision_queries",
        comment_photos: "media.operations.claim_photos",
        contract: "contracts.decision_comment_contract",
      ]
    end
  end
end
