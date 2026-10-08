# frozen_string_literal: true

module API
  module Endpoints
    class AddDecisionComment < DecisionEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID.merge(description: "the decision to comment on"),
          body: { type: "string", description: "the comment, in Markdown" },
        },
        required: %w[id body],
      }.freeze

      REPLY = Serializers::DecisionComment.reference

      include Deps[add_decision_comment: "decisions.operations.add_decision_comment"]

      def handle(id:, body:)
        case add_decision_comment.call(id, { body: })
          in Success(comment) then Success(serialized(Serializers::DecisionComment, comment))
          in result then settled(result, id)
        end
      end
    end
  end
end
