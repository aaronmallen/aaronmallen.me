# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Start < Action
        STARTED = "tasks_page.toasts.started"
        TODAY = Blog::Types::TaskFilter["today"]

        include Redirect
        include Deps[start_task: "tasks.operations.start_task"]

        def handle(request, response)
          case start_task.call(record_id(request))
          in Success(_)
            toast(response, STARTED)
            response.redirect_to(back_here(request) || tasks_path(request, filter: TODAY))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
