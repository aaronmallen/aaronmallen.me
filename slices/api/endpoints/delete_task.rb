# frozen_string_literal: true

module API
  module Endpoints
    class DeleteTask < Endpoint
      SCHEMA = { additionalProperties: false, properties: { id: Tasks::ID }, required: ["id"] }.freeze
      REPLY = Schema.object({ id: Schema::INTEGER, title: Schema::STRING, deleted: Schema::BOOLEAN }).freeze

      include Deps[delete_task: "tasks.operations.delete_task"]

      def handle(id:)
        case delete_task.call(id)
        in Success(task) then Success(id: task.id, title: task.title, deleted: true)
        in Failure(:not_found) then not_found(Tasks.missing(id))
        else failed(Tasks::UNSAVED)
        end
      end
    end
  end
end
