# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Edit < Action
        KIND = Blog::Types::RecordKind["project"]

        include Deps[
          build_project_editor: "operations.build_project_editor",
          list_record_links: "operations.list_record_links",
          project_by_id: "projects.queries.by_id",
        ]

        def handle(request, response)
          project = project_by_id.call(record_id(request))
          not_found(response) unless project

          records = list_record_links.call(KIND, project.id, query: request.params[:record_q])
          response.render(view, **build_project_editor.call(project:), records:)
        end
      end
    end
  end
end
