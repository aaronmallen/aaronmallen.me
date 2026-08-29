# frozen_string_literal: true

module MCP
  module Tools
    class RemoveTaskType < TaskTool
      KEPT = "kept: %s tasks still carry it"
      KEPT_ONE = "kept: %s task still carries it"
      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Remove one task type no task carries. A type some task still carries stays"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:)
          case remove_task_type(server_context).call(id)
          in Success(type) then answer(id: type.id, name: type.name, removed: true)
          in Failure[:in_use, held] then refuse(format(held == 1 ? KEPT_ONE : KEPT, held))
          in Failure(:not_found) then no_type(id)
          else unsaved
          end
        end
      end
    end
  end
end
