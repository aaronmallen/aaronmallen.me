# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Update < Action
        KIND = Blog::Types::RecordKind["project"]
        SAVED = "projects_page.toasts.saved"

        include Deps[
          add_repo_rule: "tasks.operations.add_repo_rule",
          build_project_editor: "operations.build_project_editor",
          list_record_links: "operations.list_record_links",
          project_queries: "projects.repos.project_queries",
          save_project: "projects.operations.save_project",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:project]]

          result = save(params, id)

          settle(response, result, SAVED, routes.path(:admin_edit_project, id:)) do |errors|
            invalid(response, project_queries.by_id(id), params, errors)
          end
        end

        private

        def invalid(response, project, params, errors)
          halt :not_found unless project

          response.status = :unprocessable_content
          records = list_record_links.call(KIND, project.id)
          response.render(view, **build_project_editor.call(project:, params:, errors:), records:)
        end

        def save(params, id)
          was = project_queries.by_id(id)&.repo

          save_project.call(params, id:).fmap { add_repo_rule.call(it, was:) }
        end
      end
    end
  end
end
