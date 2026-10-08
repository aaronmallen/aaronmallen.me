# frozen_string_literal: true

module API
  module Endpoints
    class ResolveDecision < DecisionEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Decisions::ID,
          option_id: Helpers::Schema::ID.merge(description: "the option picked, one of this decision's own"),
          reason: Decisions::REASON,
        },
        required: %w[id option_id reason],
      }.freeze

      include Deps[resolve_decision: "decisions.operations.resolve_decision"]

      def handle(id:, option_id:, reason:) = settled(resolve_decision.call(id, { option_id:, reason: }), id)
    end
  end
end
