# frozen_string_literal: true

module MCP
  module Tools
    class UnlinkTask < TaskTool
      SCHEMA = {
        additionalProperties: false,
        properties: { id: { type: "integer" }, other_id: { type: "integer" } },
        required: %w[id other_id],
      }.freeze

      description "Remove the link between two tasks, whichever way it runs"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, other_id:, server_context:)
          case unlink_task(server_context).call(id, other_id)
          in Success(*) then task_answer(id, server_context)
          in Failure(:not_found) then refuse("task #{id} has no link to task #{other_id}")
          else unsaved
          end
        end
      end
    end
  end
end
