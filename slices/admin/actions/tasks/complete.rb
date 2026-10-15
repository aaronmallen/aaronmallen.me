# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Complete < Action
        CLOSED = "tasks_page.toasts.closed"
        COMPLETED = "tasks_page.toasts.completed"
        REFUSED = "tasks_page.toasts.total_refused"

        include Redirect
        include Deps[complete_task: "tasks.operations.complete_task"]

        def handle(request, response)
          result = complete_task.call(record_id(request), worked: Blog::Types::Fields[request.params[:worked]])

          case result
            in Failure(:closed) then redirect_with(request, response, CLOSED)
            in Failure[:invalid, _] then redirect_with(request, response, REFUSED)
            else settle(response, result, COMPLETED, tasks_path(request))
          end
        end
      end
    end
  end
end
