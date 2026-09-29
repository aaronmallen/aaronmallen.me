# frozen_string_literal: true

module MCP
  module Tools
    class ReorderTask < TaskTool
      SCHEMA = {
        additionalProperties: false,
        properties: { direction: { type: "string", enum: DIRECTIONS }, id: { type: "integer" } },
        required: %w[id direction],
      }.freeze

      description "Move one open task a place up or down among the open tasks in its list or sprint. " \
                  "At either end, or once done or canceled, it stays put and moved comes back false"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, direction:, server_context:)
          case reorder_task(server_context).call(id, direction)
          in Success(*) then task_answer(id, server_context, moved: true)
          in Failure(:not_moved) then task_answer(id, server_context, moved: false)
          in Failure(:not_found) then no_task(id)
          else unsaved
          end
        end
      end
    end
  end
end
