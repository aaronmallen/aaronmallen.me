# frozen_string_literal: true

module API
  module Endpoints
    class DeleteTask < Endpoint
      SCHEMA = Helpers::Schema.by_id
      REPLY = Helpers::Schema.object(
        { id: Helpers::Schema::INTEGER, title: Helpers::Schema::STRING, deleted: Helpers::Schema::BOOLEAN },
      ).freeze

      include Deps[delete_task: "tasks.operations.delete_task"]

      def handle(id:)
        case delete_task.call(id)
          in Success(task) then Success(id: task.id, title: task.title, deleted: true)
          in Failure(:not_found) then not_found(Helpers::Wording.missing("task", id))
          else failed(Helpers::Wording::UNSAVED)
        end
      end
    end
  end
end
