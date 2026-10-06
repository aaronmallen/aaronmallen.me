# frozen_string_literal: true

module Admin
  module Actions
    module Projects
      class DestroyWork < Action
        REMOVED = "projects_page.toasts.role_removed"
        WORK = Blog::Types::ProjectFilter["work"]

        include Deps[delete_work_entry: "projects.operations.delete_work_entry"]

        def handle(request, response)
          result = delete_work_entry.call(record_id(request))
          settle(response, result, REMOVED, routes.path(:admin_projects, filter: WORK))
        end
      end
    end
  end
end
