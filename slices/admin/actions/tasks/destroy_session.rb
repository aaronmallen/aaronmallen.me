# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class DestroySession < Action
        DELETED = "tasks_page.toasts.session_deleted"

        include PageForm
        include Redirect
        include Deps[delete_work_session: "tasks.operations.delete_work_session"]

        def handle(request, response)
          id = Blog::Types::IdParam[request.params[:session_id]] || halt(404)

          case delete_work_session.call(record_id(request), id)
          in Success(_) then written(request, response, DELETED)
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end
      end
    end
  end
end
