# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class CreateSession < PageAction
        SAVED = "tasks_page.toasts.session_added"

        include Deps[add_work_session: "tasks.operations.add_work_session"]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:session]]

          result = add_work_session.call(record_id(request), params)

          settle(response, result, SAVED, tasks_path(request)) do |errors|
            refuse(request, response, adding: { values: params, errors: })
          end
        end
      end
    end
  end
end
