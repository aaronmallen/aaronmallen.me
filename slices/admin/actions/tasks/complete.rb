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
            in Failure(:closed) then answer(request, response, CLOSED)
            in Failure[:invalid, _] then answer(request, response, REFUSED)
            else settle(response, result, COMPLETED, back_path(request))
          end
        end

        private

        def answer(request, response, key)
          toast(response, key)
          response.redirect_to(back_path(request))
        end

        def back_path(request) = back_here(request) || tasks_path(request)
      end
    end
  end
end
