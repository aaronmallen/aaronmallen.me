# frozen_string_literal: true

module API
  module Endpoints
    class EditTaskComment < TaskEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Tasks::ID,
          comment_id: Tasks::ID,
          body: { type: "string", description: "the comment, in Markdown" },
        },
        required: %w[id comment_id body],
      }.freeze

      REPLY = Serializers::TaskComment.reference

      include Deps[edit_task_comment: "tasks.operations.edit_task_comment"]

      def handle(id:, comment_id:, body:)
        case edit_task_comment.call(id, comment_id, { body: })
        in Success(comment) then Success(serialized(Serializers::TaskComment, comment))
        in Failure(:not_found) then not_found(Tasks.missing_comment(id, comment_id))
        in Failure[:invalid, errors] then rejected(errors)
        else failed(Tasks::UNSAVED)
        end
      end
    end
  end
end
