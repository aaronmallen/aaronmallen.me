# frozen_string_literal: true

module API
  module Endpoints
    class ReorderTask < TaskEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { direction: { type: "string", enum: Tasks::DIRECTIONS }, id: Tasks::ID },
        required: %w[id direction],
      }.freeze

      include Deps[reorder_task: "tasks.operations.reorder_task"]

      def handle(id:, direction:)
        case reorder_task.call(id, direction)
        in Success(*) then answered(id, moved: true)
        in Failure(:not_moved) then answered(id, moved: false)
        in Failure(:not_found) then not_found(Tasks.missing(id))
        else failed(Tasks::UNSAVED)
        end
      end
    end
  end
end
