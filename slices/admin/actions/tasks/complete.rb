# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Complete < Action
        COMPLETED = "tasks_page.toasts.completed"
        REFUSED = "tasks_page.toasts.total_refused"

        include Redirect
        include Deps[complete_task: "tasks.operations.complete_task"]

        def handle(request, response)
          case complete_task.call(record_id(request), worked: Blog::Types::Fields[request.params[:worked]])
          in Success(_) then answer(request, response, COMPLETED)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, _] then answer(request, response, REFUSED)
          else halt 500
          end
        end

        private

        def answer(request, response, key)
          toast(response, key)
          response.redirect_to(tasks_path(request))
        end
      end
    end
  end
end
