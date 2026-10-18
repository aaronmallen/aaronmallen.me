# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Artifacts
        class Edit < Action
          include Deps[
            artifact_queries: "agents.repos.artifact_queries",
            build_artifact_editor: "operations.build_artifact_editor",
          ]

          def handle(request, response)
            artifact = artifact_queries.by_id(record_id(request))
            not_found(response) unless artifact

            response.render(view, **build_artifact_editor.call(artifact:))
          end
        end
      end
    end
  end
end
