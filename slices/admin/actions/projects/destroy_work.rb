# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class DestroyWork < Action
        REMOVED = "projects_page.toasts.role_removed"
        WORK = Blog::Types::ProjectFilter["work"]

        include Deps[delete_work_entry: "projects.operations.delete_work_entry"]

        def handle(request, response)
          case delete_work_entry.call(record_id(request))
          in Success(_)
            toast(response, REMOVED)
            response.redirect_to(routes.path(:admin_projects, filter: WORK))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
