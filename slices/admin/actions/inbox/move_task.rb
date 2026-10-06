# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class MoveTask < Action
        MOVED = "tasks_page.toasts.moved"

        include Deps[move_task: "tasks.operations.move_task"]

        def handle(request, response)
          result = move_task.call(record_id(request), request.params[:filter])
          settle(response, result, MOVED, routes.path(:admin_inbox))
        end
      end
    end
  end
end
