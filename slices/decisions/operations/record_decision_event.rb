# frozen_string_literal: true

module Decisions
  module Operations
    class RecordDecisionEvent
      include Deps[
        claim_decision_photos: "operations.claim_decision_photos",
        decision_mutations: "repos.decision_mutations",
      ]

      def call(decision_id, kind, **)
        event = decision_mutations.record(decision_id, kind, **)
        claim_decision_photos.call(decision_id)
        event
      end
    end
  end
end
