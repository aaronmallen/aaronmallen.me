# frozen_string_literal: true

module Decisions
  module Operations
    class EditDecisionComment < Blog::EditCommentOperation
      PHOTO_OWNER = Blog::Types::PhotoOwner["decision_comment"]

      include Deps[
        comment_mutations: "repos.decision_comment_mutations",
        comment_photos: "media.operations.claim_photos",
        comment_queries: "repos.decision_queries",
        contract: "contracts.decision_comment_contract",
      ]
    end
  end
end
