# frozen_string_literal: true

module API
  module Endpoints
    class AddTaskComment < TaskEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID.merge(description: "the task to comment on"),
          body: { type: "string", description: "the comment, in Markdown" },
        },
        required: %w[id body],
      }.freeze

      REPLY = Serializers::TaskComment.reference

      include Deps[add_task_comment: "tasks.operations.add_task_comment"]

      def handle(id:, body:)
        case add_task_comment.call(id, { body: })
          in Success(comment) then Success(serialized(Serializers::TaskComment, comment))
          in Failure(:not_found) then not_found(Helpers::Wording.missing("task", id))
          in Failure[:invalid, errors] then rejected(errors, Tasks::COMPLAINTS)
          else failed(Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
