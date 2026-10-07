# frozen_string_literal: true

module API
  module Endpoints
    class EditDecisionComment < DecisionEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Decisions::ID,
          comment_id: Decisions::ID,
          body: { type: "string", description: "the comment, in Markdown" },
        },
        required: %w[id comment_id body],
      }.freeze

      REPLY = Serializers::DecisionComment.reference

      include Deps[edit_decision_comment: "decisions.operations.edit_decision_comment"]

      def handle(id:, comment_id:, body:)
        case edit_decision_comment.call(id, comment_id, { body: })
          in Success(comment) then Success(serialized(Serializers::DecisionComment, comment))
          in Failure(:not_found) then not_found(Decisions.missing_comment(id, comment_id))
          in result then settled(result, id)
        end
      end
    end
  end
end
