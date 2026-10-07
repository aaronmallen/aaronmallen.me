# frozen_string_literal: true

module MCP
  module Tools
    class ArchiveProject < Base
      UNARCHIVED = "could not archive the project"

      description "Archive one project as of today, which takes it off /projects. " \
                  "A project whose start month has not come yet stays as it is"
      input_schema(API::Schema.by_id)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:)
          case dep(:archive_project, server_context).call(id)
            in Success(project) then answer(id:, status: project.status, archived_on: project.archived_on.iso8601)
            in Failure(:not_started) then refuse("not archived: its start month has not come yet")
            in Failure(:not_found) then refuse(API::Wording.missing("project", id))
            else refuse(UNARCHIVED)
          end
        end
      end
    end
  end
end
