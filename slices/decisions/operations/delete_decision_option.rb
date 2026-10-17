# frozen_string_literal: true

module Decisions
  module Operations
    class DeleteDecisionOption < Blog::Operation
      CHOSEN = "decisions_resolved_option_fkey"
      PHOTO_OWNER = Blog::Types::PhotoOwner["decision_option"]

      include Deps[
        claim_decision_photos: "operations.claim_decision_photos",
        decision_option_mutations: "repos.decision_option_mutations",
        decision_queries: "repos.decision_queries",
        release_photos: "media.operations.release_photos",
      ]

      def call(decision_id, id)
        step find(decision_id, id)
        step remove(decision_id, id)
      end

      private

      def find(decision_id, id) = found(decision_queries.option_on_decision(decision_id, id) && id)

      def release(decision_id, id)
        count = decision_option_mutations.delete(id)
        release_photos.call(PHOTO_OWNER, id)
        claim_decision_photos.call(decision_id)
        count
      end

      def remove(decision_id, id)
        constrained(decision_option_mutations, CHOSEN => [:id, "chosen"]) do
          Success(transaction { release(decision_id, id) })
        end
      end
    end
  end
end
