# frozen_string_literal: true

module API
  module Endpoints
    class RestoreProject < ProjectEndpoint
      SCHEMA = Helpers::Schema.by_id

      include Deps[restore_project: "projects.operations.restore_project"]

      def handle(id:)
        case restore_project.call(id)
          in Success(_) then answered(id)
          in Failure(:not_found) then missing("archived project", id)
          else failed("could not restore the project")
        end
      end
    end
  end
end
