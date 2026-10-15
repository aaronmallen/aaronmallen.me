# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class UpdateSession < PageAction
        SAVED = "tasks_page.toasts.session_saved"

        include Deps[edit_work_session: "tasks.operations.edit_work_session"]

        def handle(request, response)
          id = record_id(request, :session_id)
          params = Blog::Types::Fields[request.params[:session]]

          result = edit_work_session.call(record_id(request), id, params)

          settle(response, result, SAVED, tasks_path(request)) do |errors|
            refuse(request, response, timing: { id:, values: params, errors: })
          end
        end
      end
    end
  end
end
