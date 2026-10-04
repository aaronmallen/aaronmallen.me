# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class LinkRecord < Action
        KIND = Blog::Types::RecordKind["project"]

        include RecordLinking
        include Deps[
          build_project_editor: "operations.build_project_editor",
          edit_view: "ui.views.projects.edit",
          link_records: "links.operations.link_records",
          list_record_links: "operations.list_record_links",
          project_by_id: "projects.queries.by_id",
        ]

        def handle(request, response) = link(request, response)

        private

        def record_path(_request, id) = routes.path(:admin_edit_project, id:)

        def render_refused(request, response, id, errors)
          project = project_by_id.call(id)
          halt 404 unless project

          response.render(edit_view, **build_project_editor.call(project:),
records: linked_records(request, id, errors))
        end
      end
    end
  end
end
