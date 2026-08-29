# frozen_string_literal: true

module MCP
  module Tools
    class DropSprint < TaskTool
      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Drop a sprint that has not started yet. Its tasks go back to next"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:)
          case drop_sprint(server_context).call(id)
          in Success(sprint) then answer(sprint_entry(sprint).merge(dropped: true))
          in Failure(:started) then refuse("that sprint has already started")
          in Failure(:not_found) then no_sprint(id)
          else unsaved
          end
        end
      end
    end
  end
end
