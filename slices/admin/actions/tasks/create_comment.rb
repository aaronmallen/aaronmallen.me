# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class CreateComment < Action
        ADDED = "tasks_page.toasts.comment_added"

        include PageForm
        include Redirect
        include Deps[
          add_task_comment: "tasks.operations.add_task_comment",
          build_task_page: "operations.build_task_page",
          task_view: "ui.views.tasks.show",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:comment]]

          result = add_task_comment.call(record_id(request), params)

          case result
          in Failure[:invalid, errors]
            refuse(request, response, commenting: { id: nil, body: Blog::Types::Text[params[:body]], errors: })
          else settle(response, result, ADDED, tasks_path(request))
          end
        end
      end
    end
  end
end
