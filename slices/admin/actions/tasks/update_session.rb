# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class UpdateSession < Action
        SAVED = "tasks_page.toasts.session_saved"

        include PageForm
        include Redirect
        include Deps[
          build_task_page: "operations.build_task_page",
          edit_work_session: "tasks.operations.edit_work_session",
          task_view: "ui.views.tasks.show",
        ]

        def handle(request, response)
          id = Blog::Types::IdParam[request.params[:session_id]] || halt(404)
          params = Blog::Types::Fields[request.params[:session]]

          case edit_work_session.call(record_id(request), id, params)
          in Success(_) then written(request, response, SAVED)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then refuse(request, response, timing: { id:, values: params, errors: })
          else halt 500
          end
        end
      end
    end
  end
end
