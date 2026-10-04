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
          case pause_task.call(record_id(request))
          in Success(_) then answer(request, response, STOPPED)
          in Failure(:idle) then answer(request, response, IDLE)
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end

        private

        def answer(request, response, key)
          toast(response, key)
          response.redirect_to(back_here(request) || tasks_path(request))
        end
      end
    end
  end
end
