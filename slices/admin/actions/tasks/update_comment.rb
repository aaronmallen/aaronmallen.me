# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class UpdateComment < PageAction
        SAVED = "tasks_page.toasts.comment_saved"

        include Deps[edit_task_comment: "tasks.operations.edit_task_comment"]

        def handle(request, response)
          id = Blog::Types::IdParam[request.params[:comment_id]] || halt(404)
          params = Blog::Types::Fields[request.params[:comment]]

          result = edit_task_comment.call(record_id(request), id, params)

          case result
            in Failure[:invalid, errors]
              refuse(request, response, commenting: { id:, body: Blog::Types::Text[params[:body]], errors: })
            else settle(response, result, SAVED, tasks_path(request))
          end
        end
      end
    end
  end
end
