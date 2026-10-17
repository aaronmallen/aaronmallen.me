# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class LinkRecord < LinkRecordAction
        KIND = Blog::Types::RecordKind["project"]

        include Deps[
          build_project_editor: "operations.build_project_editor",
          edit_view: "ui.views.projects.edit",
          list_record_links: "operations.list_record_links",
          project_queries: "projects.repos.project_queries",
        ]

        private

        def record_path(_request, id) = routes.path(:admin_edit_project, id:)

        def render_refused(request, response, id, errors)
          project = project_queries.by_id(id)
          halt :not_found unless project

          records = list_record_links.call(KIND, id, **records_query(request, errors))
          unprocessable(response, edit_view, **build_project_editor.call(project:), records:)
        end
      end
    end
  end
end
