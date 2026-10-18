# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Create < Action
        CREATED = "projects_page.toasts.created"

        include Deps[
          add_repo_rule: "tasks.operations.add_repo_rule",
          build_project_editor: "operations.build_project_editor",
          save_project: "projects.operations.save_project",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:project]]

          case save(params)
            in Success(project)
              toast(response, CREATED)
              response.redirect_to(routes.path(:admin_edit_project, id: project.id))
            in Failure[:invalid, errors]
              unprocessable(response, view, **build_project_editor.call(params:, errors:))
          end
        end

        private

        def save(params) = save_project.call(params).fmap { add_repo_rule.call(it) }
      end
    end
  end
end
