# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class MoveTask < Action
        MOVED = "tasks_page.toasts.moved"

        include Deps[move_task: "tasks.operations.move_task"]

        def handle(request, response)
          case move_task.call(record_id(request), request.params[:filter])
          in Success(_)
            toast(response, MOVED)
            response.redirect_to(routes.path(:admin_inbox))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
