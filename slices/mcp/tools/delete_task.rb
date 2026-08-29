# frozen_string_literal: true

module MCP
  module Tools
    class DeleteTask < TaskTool
      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Delete one task and every link to or from it. This cannot be undone"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:)
          case delete_task(server_context).call(id)
          in Success(task) then answer(id: task.id, title: task.title, deleted: true)
          in Failure(:not_found) then no_task(id)
          else unsaved
          end
        end
      end
    end
  end
end
