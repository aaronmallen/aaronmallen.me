# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Archive < Action
        ARCHIVED = "projects_page.toasts.archived"
        NOT_STARTED = "projects_page.toasts.not_started"

        include Deps[archive_project: "projects.operations.archive_project"]

        def handle(request, response)
          id = record_id(request)

          result = archive_project.call(id)

          case result
            in Failure(:not_started) then not_started(response, id)
            else settle(response, result, ARCHIVED, routes.path(:admin_projects, filter: filter(request)))
          end
        end

        private

        def filter(request) = Blog::Types::ProjectFilterParam[request.params[:filter]]

        def not_started(response, id)
          toast(response, NOT_STARTED)
          response.redirect_to(routes.path(:admin_edit_project, id:))
        end
      end
    end
  end
end
