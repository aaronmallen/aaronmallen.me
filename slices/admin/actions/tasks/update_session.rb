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

          result = edit_work_session.call(record_id(request), id, params)

          case result
            in Failure[:invalid, errors] then refuse(request, response, timing: { id:, values: params, errors: })
            else settle(response, result, SAVED, tasks_path(request))
          end
        end
      end
    end
  end
end
