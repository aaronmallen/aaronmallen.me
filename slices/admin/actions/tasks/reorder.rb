# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Reorder < Action
        include Redirect
        include Deps[reorder_task: "tasks.operations.reorder_task"]

        def handle(request, response)
          case reorder_task.call(record_id(request), request.params[:direction])
          in Success(_) | Failure(:not_moved)
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
