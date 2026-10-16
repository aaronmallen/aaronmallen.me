# frozen_string_literal: true

module Decisions
  module Operations
    class ClaimDecisionPhotos
      DECISION = Blog::Types::PhotoOwner["decision"]
      OPTION = Blog::Types::PhotoOwner["decision_option"]

      include Deps[claim_photos: "media.operations.claim_photos", decision_queries: "repos.decision_queries"]

      def call(decision_id)
        claim_photos.call(DECISION, decision_id, *decision_queries.photo_texts(decision_id))
        decision_queries.option_bodies(decision_id).each { |id, body| claim_photos.call(OPTION, id, body) }
      end
    end
  end
end
