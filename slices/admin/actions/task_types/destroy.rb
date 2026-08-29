# frozen_string_literal: true

module Admin
  module Actions
    module TaskTypes
      class Destroy < Action
        IN_USE = "task_types_page.toasts.in_use"
        REMOVED = "task_types_page.toasts.removed"

        include Deps[remove_task_type: "tasks.operations.remove_task_type"]

        def handle(request, response)
          case remove_task_type.call(record_id(request))
          in Success(_) then done(response, REMOVED)
          in Failure(:not_found) then halt 404
          in Failure[:in_use, held] then done(response, IN_USE, count: held)
          else halt 500
          end
        end

        private

        def done(response, key, **)
          toast(response, key, **)
          response.redirect_to(routes.path(:admin_task_types))
        end
      end
    end
  end
end
