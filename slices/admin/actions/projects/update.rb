# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Update < Action
        KIND = Blog::Types::RecordKind["project"]
        SAVED = "projects_page.toasts.saved"

        include Deps[
          build_project_editor: "operations.build_project_editor",
          list_record_links: "operations.list_record_links",
          project_by_id: "projects.queries.by_id",
          save_project: "projects.operations.save_project",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:project]]

          case save_project.call(params, id:)
          in Success(project) then saved(response, project)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then invalid(response, project_by_id.call(id), params, errors)
          else halt 500
          end
        end

        private

        def invalid(response, project, params, errors)
          halt 404 unless project

          response.status = 422
          records = list_record_links.call(KIND, project.id)
          response.render(view, **build_project_editor.call(project:, params:, errors:), records:)
        end

        def saved(response, project)
          toast(response, SAVED)
          response.redirect_to(routes.path(:admin_edit_project, id: project.id))
        end
      end
    end
  end
end
