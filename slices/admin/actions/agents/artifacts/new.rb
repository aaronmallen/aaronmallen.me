# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Artifacts
        class New < Action
          include Deps[build_artifact_editor: "operations.build_artifact_editor"]

          def handle(_request, response)
            response.render(view, **build_artifact_editor.call)
          end
        end
      end
    end
  end
end
