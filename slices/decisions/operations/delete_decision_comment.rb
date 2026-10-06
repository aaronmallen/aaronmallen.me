# frozen_string_literal: true

module Decisions
  module Operations
    class DeleteDecisionComment < Blog::Operation
      PHOTO_OWNER = Blog::Types::PhotoOwner["decision_comment"]

      include Deps[
        decision_comment_repo: "repos.decision_comment_repo",
        release_photos: "media.operations.release_photos",
      ]

      def call(decision_id, id)
        transaction do
          count = step affected(decision_comment_repo.delete_on_decision(decision_id, id))
          release_photos.call(PHOTO_OWNER, id)
          count
        end
      end
    end
  end
end
