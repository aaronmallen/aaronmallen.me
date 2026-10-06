# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class DestroyComment < Action
        DELETED = "tasks_page.toasts.comment_deleted"

        include Redirect
        include Deps[delete_task_comment: "tasks.operations.delete_task_comment"]

        def handle(request, response)
          id = Blog::Types::IdParam[request.params[:comment_id]] || halt(404)

          settle(response, delete_task_comment.call(record_id(request), id), DELETED, tasks_path(request))
        end
      end
    end
  end
end
