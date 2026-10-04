# frozen_string_literal: true

module API
  module Endpoints
    class DeleteDecisionComment < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Decisions::ID, comment_id: Decisions::ID },
        required: %w[id comment_id],
      }.freeze

      REPLY = Schema.object({ id: Schema::INTEGER, comment_id: Schema::INTEGER, deleted: Schema::BOOLEAN }).freeze

      include Deps[delete_decision_comment: "decisions.operations.delete_decision_comment"]

      def handle(id:, comment_id:)
        case delete_decision_comment.call(id, comment_id)
        in Success(*) then Success(id:, comment_id:, deleted: true)
        in Failure(:not_found) then not_found(Decisions.missing_comment(id, comment_id))
        else failed(Wording::UNSAVED)
        end
      end
    end
  end
end
