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

          case archive_project.call(id)
          in Success(_)
            archived(request, response)
          in Failure(:not_started)
            not_started(response, id)
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end

        private

        def archived(request, response)
          toast(response, ARCHIVED)
          response.redirect_to(routes.path(:admin_projects, filter: filter(request)))
        end

        def filter(request) = Blog::Types::ProjectFilterParam[request.params[:filter]]

        def not_started(response, id)
          toast(response, NOT_STARTED)
          response.redirect_to(routes.path(:admin_edit_project, id:))
        end
      end
    end
  end
end
