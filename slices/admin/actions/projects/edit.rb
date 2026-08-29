# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class Edit < Action
        include Deps[
          build_project_editor: "operations.build_project_editor",
          project_by_id: "projects.queries.by_id",
        ]

        def handle(request, response)
          project = project_by_id.call(record_id(request))
          not_found(response) unless project

          response.render(view, **build_project_editor.call(project:))
        end
      end
    end
  end
end
