# frozen_string_literal: true

module MCP
  module Tools
    class ScheduleTask < TaskTool
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: { type: "integer" },
          sprint_on: {
            type: "string",
            description: "the sprint day as YYYY-MM-DD, today or later, or an empty string to send it back to next",
          },
        },
        required: %w[id sprint_on],
      }.freeze

      description "Schedule one task into the sprint for a day, starting that sprint when it has none yet, " \
                  "or unschedule it back to next"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, sprint_on:, server_context:)
          case schedule_task(server_context).call(id, sprint_on)
          in Success(*) then task_answer(id, server_context)
          in Failure(:past) | Failure(:invalid) then sprint_past
          in Failure(:not_found) then no_task(id)
          else unsaved
          end
        end
      end
    end
  end
end
