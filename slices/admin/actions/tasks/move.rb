# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Move < Action
        MOVED = "tasks_page.toasts.moved"

        include Redirect
        include Deps[move_task: "tasks.operations.move_task"]

        def handle(request, response)
          filter = request.params[:filter]

          case move_task.call(record_id(request), filter)
          in Success(_)
            toast(response, MOVED)
            response.redirect_to(tasks_path(request, filter:))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
