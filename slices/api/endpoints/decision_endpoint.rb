# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class DecisionEndpoint < Endpoint
      CLOSED = "decision %s is already resolved or dropped"
      REPLY = Serializers::Decision.reference

      include Deps[decision_queries: "decisions.repos.decision_queries"]

      private

      def answered(id) = Success(serialized(Serializers::Decision, decision_queries.by_id(id)))

      def closed(id) = invalid(id: [format(CLOSED, id)])

      def settled(result, id)
        case result
        in Success(*) then answered(id)
        in Failure(:not_found) then not_found(Wording.missing("decision", id))
        in Failure(:closed) then closed(id)
        in Failure[:invalid, errors] then rejected(errors, Decisions::COMPLAINTS)
        else failed(Wording::UNSAVED)
        end
      end
    end
  end
end
