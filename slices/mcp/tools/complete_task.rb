# frozen_string_literal: true

module MCP
  module Tools
    class CompleteTask < TaskTool
      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Mark one task done, stamped with the time now"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:) = settled(complete_task(server_context).call(id), id, server_context)
      end
    end
  end
end
