# frozen_string_literal: true

module API
  module Endpoints
    class ScheduleTask < TaskEndpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Tasks::ID,
          sprint_on: {
            type: "string",
            description: "the sprint day as YYYY-MM-DD, today or later, or an empty string to send it back to next",
          },
        },
        required: %w[id sprint_on],
      }.freeze

      include Deps[schedule_task: "tasks.operations.schedule_task"]

      def handle(id:, sprint_on:) = placed(schedule_task.call(id, sprint_on), id)
    end
  end
end
