# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Artifacts
        class Update < Action
          SAVED = "artifacts_page.toasts.saved"

          include Form
          include Deps[
            artifact_queries: "agents.repos.artifact_queries",
            build_artifact_editor: "operations.build_artifact_editor",
            update_artifact: "agents.operations.update_artifact",
          ]

          def handle(request, response)
            params = artifact_params(request)
            result = update_artifact.call(record_id(request), params)

            settle(response, result, SAVED, artifact_path(request)) do |errors|
              artifact = artifact_queries.by_id(record_id(request))
              halt :not_found unless artifact

              unprocessable(response, view, **build_artifact_editor.call(artifact:, params:, errors:))
            end
          end
        end
      end
    end
  end
end
