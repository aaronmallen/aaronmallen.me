# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Destroy < Action
        DELETED = "tasks_page.toasts.deleted"

        include Redirect
        include Deps[delete_task: "tasks.operations.delete_task"]

        def handle(request, response)
          settle(response, delete_task.call(record_id(request)), DELETED, tasks_path(request))
        end
      end
    end
  end
end
