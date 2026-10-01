# frozen_string_literal: true

module MCP
  module Tools
    class ReadTask < TaskTool
      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Read one task: its title, note, status, list or sprint day, tags, links both ways and its " \
                  "comments, oldest first"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(id:, server_context:)
          task = task_by_id(server_context).call(id)
          return no_task(id) if task.nil?

          task_reply(task, server_context)
        end
      end
    end
  end
end
