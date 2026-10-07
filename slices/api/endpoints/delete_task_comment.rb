# frozen_string_literal: true

module API
  module Endpoints
    class DeleteTaskComment < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Tasks::ID, comment_id: Tasks::ID },
        required: %w[id comment_id],
      }.freeze

      REPLY = Schema.object({ id: Schema::INTEGER, comment_id: Schema::INTEGER, deleted: Schema::BOOLEAN }).freeze

      include Deps[delete_task_comment: "tasks.operations.delete_task_comment"]

      def handle(id:, comment_id:)
        case delete_task_comment.call(id, comment_id)
          in Success(*) then Success(id:, comment_id:, deleted: true)
          in Failure(:not_found) then not_found(Tasks.missing_comment(id, comment_id))
          else failed(Wording::UNSAVED)
        end
      end
    end
  end
end
