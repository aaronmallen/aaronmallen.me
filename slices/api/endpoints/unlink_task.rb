# frozen_string_literal: true

module API
  module Endpoints
    class UnlinkTask < TaskEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { id: Tasks::ID, other_id: Tasks::ID },
        required: %w[id other_id],
      }.freeze

      include Deps[unlink_task: "tasks.operations.unlink_task"]

      def handle(id:, other_id:)
        case unlink_task.call(id, other_id)
          in Success(*) then answered(id)
          in Failure(:not_found) then not_found("task #{id} has no link to task #{other_id}")
          else failed(Wording::UNSAVED)
        end
      end
    end
  end
end
