# frozen_string_literal: true

module API
  module Endpoints
    class ArchiveProject < ProjectEndpoint
      ARCHIVED = "not archived: it is archived already"
      NOT_STARTED = "not archived: its start month has not come yet"
      SCHEMA = Helpers::Schema.by_id

      include Deps[archive_project: "projects.operations.archive_project"]

      def handle(id:)
        case archive_project.call(id)
          in Success(_) then answered(id)
          in Failure(:archived) then invalid(id: [ARCHIVED])
          in Failure(:not_started) then invalid(id: [NOT_STARTED])
          in Failure(:not_found) then missing("project", id)
          in unmatched then unhandled(unmatched, "could not archive the project")
        end
      end
    end
  end
end
