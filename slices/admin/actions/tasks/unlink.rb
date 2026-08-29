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

          case unlink_task.call(record_id(request), other_id)
          in Success(_)
            toast(response, UNLINKED)
            response.redirect_to(tasks_path(request))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
