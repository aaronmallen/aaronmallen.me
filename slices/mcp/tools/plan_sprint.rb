# frozen_string_literal: true

module MCP
  module Tools
    class PlanSprint < TaskTool
      SCHEMA = {
        additionalProperties: false,
        properties: { sprint_on: { type: "string", description: "a day after today, as YYYY-MM-DD" } },
        required: ["sprint_on"],
      }.freeze

      description "Plan the sprint for a day after today, so tasks can be scheduled into it before it starts"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(sprint_on:, server_context:)
          case plan_sprint(server_context).call(sprint_on)
          in Success(sprint) then answer(sprint_entry(sprint))
          in Failure[:planned, day] then refuse("a sprint already exists for #{day.iso8601}")
          in Failure(:past) then refuse("plan a sprint for a day after today")
          in Failure(:invalid) then refuse("pick a day first, such as 2026-01-01")
          else unsaved
          end
        end
      end
    end
  end
end
