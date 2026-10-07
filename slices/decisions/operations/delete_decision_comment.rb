# frozen_string_literal: true

module Decisions
  module Operations
    class DeleteDecisionComment < Operation
      PHOTO_OWNER = Blog::Types::PhotoOwner["decision_comment"]

      include Deps[
        decision_comment_mutations: "repos.decision_comment_mutations",
        release_photos: "media.operations.release_photos",
      ]

      def call(decision_id, id)
        transaction do
          count = step affected(decision_comment_mutations.delete_on_decision(decision_id, id))
          release_photos.call(PHOTO_OWNER, id)
          count
        end
      end
    end
  end
end
