# frozen_string_literal: true

module MCP
  module Tools
    class CancelTask < TaskTool
      CLOSED = "task %s is already done or canceled"
      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Cancel one open or started task, stamped with the time now. It closes without counting as work " \
                  "done, so the activity feed leaves it out"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:)
          case cancel_task(server_context).call(id)
          in Failure(:closed) then refuse(format(CLOSED, id))
          in result then settled(result, id, server_context)
          end
        end
      end
    end
  end
end
