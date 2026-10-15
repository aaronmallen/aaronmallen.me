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

          settle(response, result, SAVED, tasks_path(request)) do |errors|
            refuse(request, response, totaling: { values: params, errors: })
          end
        end
      end
    end
  end
end
