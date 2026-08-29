# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Destroy < Action
        DELETED = "tasks_page.toasts.deleted"

        include Redirect
        include Deps[delete_task: "tasks.operations.delete_task"]

        def handle(request, response)
          case delete_task.call(record_id(request))
          in Success(_)
            toast(response, DELETED)
            response.redirect_to(tasks_path(request))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
