# frozen_string_literal: true

module MCP
  module Tools
    class ReorderTaskType < TaskTool
      SCHEMA = {
        additionalProperties: false,
        properties: { direction: { type: "string", enum: DIRECTIONS }, id: { type: "integer" } },
        required: %w[id direction],
      }.freeze

      description "Move one task type a place up or down. At either end it stays put and moved comes back false"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, direction:, server_context:)
          case reorder_task_type(server_context).call(id, direction)
          in Success(*) then answer(id:, moved: true)
          in Failure(:not_moved) then answer(id:, moved: false)
          in Failure(:not_found) then no_type(id)
          else unsaved
          end
        end
      end
    end
  end
end
