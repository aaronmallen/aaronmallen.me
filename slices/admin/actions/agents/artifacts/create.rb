# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Artifacts
        class Create < Action
          CREATED = "artifacts_page.toasts.created"

          include Form
          include Deps[
            build_artifact_editor: "operations.build_artifact_editor",
            create_artifact: "agents.operations.create_artifact",
          ]

          def handle(request, response)
            params = artifact_params(request)

            case create_artifact.call(params)
              in Success(artifact)
                toast_back(response, CREATED, routes.path(:admin_artifact, id: artifact.id))
              in Failure[:invalid, errors]
                unprocessable(response, view, **build_artifact_editor.call(params:, errors:))
              else halt :internal_server_error
            end
          end
        end
      end
    end
  end
end
