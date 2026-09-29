# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class CreateComment < Action
        ADDED = "tasks_page.toasts.comment_added"

        include CommentForm
        include Redirect
        include Deps[
          add_task_comment: "tasks.operations.add_task_comment",
          build_task_page: "operations.build_task_page",
          task_view: "ui.views.tasks.show",
        ]

        def handle(request, response)
          params = comment_params(request)

          case add_task_comment.call(record_id(request), params)
          in Success(_) then written(request, response, ADDED)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors]
            refuse_comment(request, response, { id: nil, body: Blog::Types::Text[params[:body]], errors: })
          else halt 500
          end
        end
      end
    end
  end
end
