# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class DestroyComment < Action
        DELETED = "tasks_page.toasts.comment_deleted"

        include CommentForm
        include Redirect
        include Deps[delete_task_comment: "tasks.operations.delete_task_comment"]

        def handle(request, response)
          id = Blog::Types::IdParam[request.params[:comment_id]] || halt(404)

          case delete_task_comment.call(record_id(request), id)
          in Success(_) then written(request, response, DELETED)
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end
      end
    end
  end
end
