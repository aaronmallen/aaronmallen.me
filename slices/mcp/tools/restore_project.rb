# frozen_string_literal: true

module MCP
  module Tools
    class RestoreProject < Base
      UNRESTORED = "could not restore the project"

      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Restore one archived project to /projects as active"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:)
          case restore_project(server_context).call(id)
          in Success(project) then answer(id:, status: project.status)
          in Failure(:not_found) then refuse("no archived project has the ID #{id}")
          else refuse(UNRESTORED)
          end
        end
      end
    end
  end
end
