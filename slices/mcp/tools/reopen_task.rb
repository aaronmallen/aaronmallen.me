# frozen_string_literal: true

module MCP
  module Tools
    class ReopenTask < TaskTool
      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Reopen one task, done, canceled or started: it goes back to open where it sits"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:) = settled(reopen_task(server_context).call(id), id, server_context)
      end
    end
  end
end
