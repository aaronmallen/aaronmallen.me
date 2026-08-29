# frozen_string_literal: true

module MCP
  module Tools
    class MoveTask < TaskTool
      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: { type: "integer" },
          list: { type: "string", enum: LISTS, description: "today puts it in today's sprint" },
        },
        required: %w[id list],
      }.freeze

      description "Move one task to next, someday or today's sprint"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, list:, server_context:) = settled(move_task(server_context).call(id, list), id, server_context)
      end
    end
  end
end
