# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class CreateComment < PageAction
        ADDED = "tasks_page.toasts.comment_added"

        include Deps[add_task_comment: "tasks.operations.add_task_comment"]

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
