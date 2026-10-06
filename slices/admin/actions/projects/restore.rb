# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Restore < Action
        RESTORED = "projects_page.toasts.restored"

        include Deps[restore_project: "projects.operations.restore_project"]

        def handle(request, response)
          result = restore_project.call(record_id(request))
          settle(response, result, RESTORED, routes.path(:admin_projects, filter: filter(request)))
        end

        private

        def filter(request) = Blog::Types::ProjectFilterParam[request.params[:filter]]
      end
    end
  end
end
