# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class UpdateTotal < PageAction
        SAVED = "tasks_page.toasts.total_saved"

        include Deps[set_task_total: "tasks.operations.set_task_total"]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:total]]

          result = set_task_total.call(record_id(request), params)

          case result
            in Failure[:invalid, errors] then refuse(request, response, totaling: { values: params, errors: })
            else settle(response, result, SAVED, tasks_path(request))
          end
        end
      end
    end
  end
end
