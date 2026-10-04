# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class DecisionEndpoint < Endpoint
      CLOSED = "decision %s is already resolved or dropped"
      REPLY = Serializers::Decision.reference

      include Deps[decision_by_id: "decisions.queries.by_id"]

      private

      def answered(id) = Success(serialized(Serializers::Decision, decision_by_id.call(id)))

      def closed(id) = invalid(id: [format(CLOSED, id)])

      def rejected(errors)
        complaints = Decisions.complaints(errors)

        Failure(Refusal.invalid(complaints, message: Decisions.summary(complaints)))
      end

      def settled(result, id)
        case result
        in Success(*) then answered(id)
        in Failure(:not_found) then not_found(Decisions.missing(id))
        in Failure(:closed) then closed(id)
        in Failure[:invalid, errors] then rejected(errors)
        else failed(Decisions::UNSAVED)
        end
      end
    end
  end
end
