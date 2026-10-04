# frozen_string_literal: true

module API
  module Endpoints
    class DropDecision < DecisionEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Decisions::ID, reason: Decisions::REASON },
        required: %w[id reason],
      }.freeze

      include Deps[drop_decision: "decisions.operations.drop_decision"]

      def handle(id:, reason:) = settled(drop_decision.call(id, { reason: }), id)
    end
  end
end
