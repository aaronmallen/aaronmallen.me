# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Artifacts
        class Destroy < Action
          DELETED = "artifacts_page.toasts.deleted"

          include Deps[delete_artifact: "agents.operations.delete_artifact"]

          def handle(request, response)
            settle(response, delete_artifact.call(record_id(request)), DELETED, routes.path(:admin_artifacts))
          end
        end
      end
    end
  end
end
