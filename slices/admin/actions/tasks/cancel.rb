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
          case cancel_task.call(record_id(request))
          in Success(_) then done(request, response, CANCELED)
          in Failure(:closed) then done(request, response, CLOSED)
          in Failure(:not_found) then halt 404
          else halt 500
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
