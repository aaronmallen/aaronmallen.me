# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class UpdateTotal < Action
        SAVED = "tasks_page.toasts.total_saved"

        include PageForm
        include Redirect
        include Deps[
          build_task_page: "operations.build_task_page",
          set_task_total: "tasks.operations.set_task_total",
          task_view: "ui.views.tasks.show",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:total]]

          case set_task_total.call(record_id(request), params)
          in Success(_) then written(request, response, SAVED)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then refuse(request, response, totaling: { values: params, errors: })
          else halt 500
          end
        end
      end
    end
  end
end
