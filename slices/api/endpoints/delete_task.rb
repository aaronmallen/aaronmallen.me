# frozen_string_literal: true

module API
  module Endpoints
    class DeleteTask < Endpoint
      SCHEMA = Schema.by_id
      REPLY = Schema.object({ id: Schema::INTEGER, title: Schema::STRING, deleted: Schema::BOOLEAN }).freeze

      include Deps[delete_task: "tasks.operations.delete_task"]

      def handle(id:)
        case delete_task.call(id)
        in Success(task) then Success(id: task.id, title: task.title, deleted: true)
        in Failure(:not_found) then not_found(Tasks.missing(id))
        else failed(Wording::UNSAVED)
        end
      end
    end
  end
end
