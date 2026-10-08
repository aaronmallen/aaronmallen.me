# frozen_string_literal: true

module API
  module Endpoints
    class AddDecisionOption < DecisionEndpoint
      CLOSED = "decision %s is resolved or dropped, so reopen it to add an option"

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID.merge(description: "the open decision to add it to"),
          title: { type: "string" },
          body: { type: "string", description: "the option, in Markdown, pros and cons included" },
        },
        required: %w[id title],
      }.freeze

      REPLY = Serializers::DecisionOption.reference

      include Deps[add_decision_option: "decisions.operations.add_decision_option"]

      def handle(id:, title:, body: "")
        case add_decision_option.call(id, { title:, body: })
          in Success(option) then Success(serialized(Serializers::DecisionOption, option))
          in Failure(:closed) then invalid(id: [format(CLOSED, id)])
          in result then settled(result, id)
        end
      end
    end
  end
end
