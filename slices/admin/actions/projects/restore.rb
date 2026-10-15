# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Restore < Action
        RESTORED = "projects_page.toasts.restored"

        include Redirect
        include Deps[restore_project: "projects.operations.restore_project"]

        def handle(request, response)
          result = restore_project.call(record_id(request))
          settle(response, result, RESTORED, back_path(request))
        end
      end
    end
  end
end
