# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Complete < Action
        COMPLETED = "tasks_page.toasts.completed"

        include Redirect
        include Deps[complete_task: "tasks.operations.complete_task"]

        def handle(request, response)
          case complete_task.call(record_id(request))
          in Success(_)
            toast(response, COMPLETED)
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
