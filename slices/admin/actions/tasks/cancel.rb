# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Cancel < Action
        CANCELED = "tasks_page.toasts.canceled"
        CLOSED = "tasks_page.toasts.closed"

        include Redirect
        include Deps[cancel_task: "tasks.operations.cancel_task"]

        def handle(request, response)
          result = cancel_task.call(record_id(request))

          case result
            in Failure(:closed) then done(request, response, CLOSED)
            else settle(response, result, CANCELED, tasks_path(request))
          end
        end

        private

        def done(request, response, key)
          toast(response, key)
          response.redirect_to(tasks_path(request))
        end
      end
    end
  end
end
