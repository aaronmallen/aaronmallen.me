# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Stop < Action
        IDLE = "tasks_page.toasts.idle"
        STOPPED = "tasks_page.toasts.stopped"

        include Redirect
        include Deps[pause_task: "tasks.operations.pause_task"]

        def handle(request, response)
          result = pause_task.call(record_id(request))

          case result
            in Failure(:idle) then redirect_with(request, response, IDLE)
            else settle(response, result, STOPPED, tasks_path(request))
          end
        end
      end
    end
  end
end
