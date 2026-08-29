# frozen_string_literal: true

module MCP
  module Tools
    class ArchiveProject < Base
      UNARCHIVED = "could not archive the project"

      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Archive one project as of today, which takes it off /projects and unfeatures it. " \
                  "A project whose start month has not come yet stays as it is"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:)
          case archive_project(server_context).call(id)
          in Success(project) then answer(id:, status: project.status, archived_on: project.archived_on.iso8601)
          in Failure(:not_started) then refuse("not archived: its start month has not come yet")
          in Failure(:not_found) then refuse("no project has the ID #{id}")
          else refuse(UNARCHIVED)
          end
        end
      end
    end
  end
end
