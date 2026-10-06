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
          pool = request.params[:pool]&.then { Blog::Types::TaskListParam[it] }

          settle(response, move_task.call(record_id(request), filter), MOVED, tasks_path(request, filter:, pool:))
        end
      end
    end
  end
end
