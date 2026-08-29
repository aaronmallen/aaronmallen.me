# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Restore < Action
        RESTORED = "projects_page.toasts.restored"

        include Deps[restore_project: "projects.operations.restore_project"]

        def handle(request, response)
          case restore_project.call(record_id(request))
          in Success(_)
            restored(request, response)
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end

        private

        def filter(request) = Blog::Types::ProjectFilterParam[request.params[:filter]]

        def restored(request, response)
          toast(response, RESTORED)
          response.redirect_to(routes.path(:admin_projects, filter: filter(request)))
        end
      end
    end
  end
end
