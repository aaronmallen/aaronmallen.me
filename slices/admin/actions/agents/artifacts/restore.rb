# frozen_string_literal: true

module Admin
  module Actions
    module Agents
      module Artifacts
        class Restore < Action
          RESTORED = "artifacts_page.toasts.restored"

          include Form
          include Deps[restore_artifact_version: "agents.operations.restore_artifact_version"]

          def handle(request, response)
            result = restore_artifact_version.call(record_id(request), record_id(request, :number), {})

            settle(response, result, RESTORED, artifact_path(request))
          end
        end
      end
    end
  end
end
