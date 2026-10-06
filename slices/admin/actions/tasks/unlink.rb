# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Unlink < Action
        UNLINKED = "tasks_page.toasts.unlinked"

        include Redirect
        include Deps[unlink_task: "tasks.operations.unlink_task"]

        def handle(request, response)
          other_id = Blog::Types::IdParam[request.params[:other_id]] || halt(404)

          settle(response, unlink_task.call(record_id(request), other_id), UNLINKED, tasks_path(request))
        end
      end
    end
  end
end
