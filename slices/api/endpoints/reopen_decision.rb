# frozen_string_literal: true

module API
  module Endpoints
    class ReopenDecision < DecisionEndpoint
      OPEN = "decision %s is already open"

      SCHEMA = {
        additionalProperties: false,
        properties: { id: Decisions::ID, reason: Decisions::REASON },
        required: %w[id reason],
      }.freeze

      include Deps[reopen_decision: "decisions.operations.reopen_decision"]

      def handle(id:, reason:)
        case reopen_decision.call(id, { reason: })
        in Failure(:open) then invalid(id: [format(OPEN, id)])
        in result then settled(result, id)
        end
      end
    end
  end
end
