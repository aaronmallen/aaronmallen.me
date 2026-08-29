# frozen_string_literal: true

module MCP
  module Tools
    class StartTask < TaskTool
      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Start one task: it joins today's sprint and shows as in progress"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:) = settled(start_task(server_context).call(id), id, server_context)
      end
    end
  end
end
