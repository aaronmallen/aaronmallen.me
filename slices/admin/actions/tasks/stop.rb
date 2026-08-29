# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Stop < Action
        STOPPED = "tasks_page.toasts.stopped"

        include Redirect
        include Deps[reopen_task: "tasks.operations.reopen_task"]

        def handle(request, response)
          case reopen_task.call(record_id(request))
          in Success(_)
            toast(response, STOPPED)
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
