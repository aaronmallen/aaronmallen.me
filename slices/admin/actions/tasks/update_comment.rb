# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class UpdateComment < Action
        SAVED = "tasks_page.toasts.comment_saved"

        include CommentForm
        include Redirect
        include Deps[
          build_task_page: "operations.build_task_page",
          edit_task_comment: "tasks.operations.edit_task_comment",
          task_view: "ui.views.tasks.show",
        ]

        def handle(request, response)
          id = Blog::Types::IdParam[request.params[:comment_id]] || halt(404)
          params = comment_params(request)

          case edit_task_comment.call(record_id(request), id, params)
          in Success(_) then written(request, response, SAVED)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors]
            refuse_comment(request, response, { id:, body: Blog::Types::Text[params[:body]], errors: })
          else halt 500
          end
        end
      end
    end
  end
end
