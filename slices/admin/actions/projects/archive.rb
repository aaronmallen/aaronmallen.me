# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Archive < Action
        ALREADY_ARCHIVED = "projects_page.toasts.already_archived"
        ARCHIVED = "projects_page.toasts.archived"
        NOT_STARTED = "projects_page.toasts.not_started"

        include Redirect
        include Deps[archive_project: "projects.operations.archive_project"]

        def handle(request, response)
          id = record_id(request)

          result = archive_project.call(id)

          case result
            in Failure(:archived) then refused(response, id, ALREADY_ARCHIVED)
            in Failure(:not_started) then refused(response, id, NOT_STARTED)
            else settle(response, result, ARCHIVED, back_path(request))
          end
        end

        private

        def refused(response, id, key)
          toast(response, key)
          response.redirect_to(routes.path(:admin_edit_project, id:))
        end
      end
    end
  end
end
