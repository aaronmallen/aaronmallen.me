# frozen_string_literal: true

module Admin
  module Actions
    module TaskTypes
      class Reorder < Action
        include Deps[reorder_task_type: "tasks.operations.reorder_task_type"]

        def handle(request, response)
          case reorder_task_type.call(record_id(request), request.params[:direction])
          in Success(_) | Failure(:not_moved)
            response.redirect_to(routes.path(:admin_task_types))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
