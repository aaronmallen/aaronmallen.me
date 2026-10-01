# frozen_string_literal: true

module API
  module Endpoints
    class MoveTask < TaskEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Tasks::ID,
          list: { type: "string", enum: Tasks::LISTS, description: "today puts it in today's sprint" },
        },
        required: %w[id list],
      }.freeze

      include Deps[move_task: "tasks.operations.move_task"]

      def handle(id:, list:) = settled(move_task.call(id, list), id)
    end
  end
end
