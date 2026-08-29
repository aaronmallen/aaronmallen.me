# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Create < Action
        CREATED = "projects_page.toasts.created"

        include Deps[
          build_project_editor: "operations.build_project_editor",
          save_project: "projects.operations.save_project",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:project]]

          case save_project.call(params)
          in Success(project)
            toast(response, CREATED)
            response.redirect_to(routes.path(:admin_edit_project, id: project.id))
          in Failure[:invalid, errors]
            response.status = 422
            response.render(view, **build_project_editor.call(params:, errors:))
          else halt 500
          end
        end
      end
    end
  end
end
