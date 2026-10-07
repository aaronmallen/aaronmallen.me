# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Update < Action
        KIND = Blog::Types::RecordKind["project"]
        SAVED = "projects_page.toasts.saved"

        include Deps[
          build_project_editor: "operations.build_project_editor",
          link_repo_tasks: "tasks.operations.link_repo_tasks",
          list_record_links: "operations.list_record_links",
          project_queries: "projects.repos.project_queries",
          save_project: "projects.operations.save_project",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:project]]

          result = save(params, id)

          case result
          in Failure[:invalid, errors] then invalid(response, project_queries.by_id(id), params, errors)
          else settle(response, result, SAVED, routes.path(:admin_edit_project, id:))
          end
        end

        private

        def invalid(response, project, params, errors)
          halt 404 unless project

          response.status = 422
          records = list_record_links.call(KIND, project.id)
          response.render(view, **build_project_editor.call(project:, params:, errors:), records:)
        end

        def save(params, id)
          was = project_queries.by_id(id)&.repo

          save_project.call(params, id:).bind { link_repo_tasks.call(it, was:) }
        end
      end
    end
  end
end
