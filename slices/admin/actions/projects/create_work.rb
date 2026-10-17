# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class CreateWork < Action
        ADDED = "projects_page.toasts.role_added"
        WORK = Blog::Types::ProjectFilter["work"]

        include Deps[
          add_work_entry: "projects.operations.add_work_entry",
          build_projects_page: "operations.build_projects_page",
          index_view: "ui.views.projects.index",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:work_entry]]

          settle(response, add_work_entry.call(params), ADDED, routes.path(:admin_projects, filter: WORK)) do |errors|
            unprocessable(response, index_view, **build_projects_page.call(filter: WORK, params:, errors:))
          end
        end
      end
    end
  end
end
