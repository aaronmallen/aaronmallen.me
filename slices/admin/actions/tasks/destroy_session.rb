# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class DestroySession < PageAction
        DELETED = "tasks_page.toasts.session_deleted"

        include Deps[delete_work_session: "tasks.operations.delete_work_session"]

        def handle(request, response)
          id = record_id(request, :session_id)

          result = delete_work_session.call(record_id(request), id)

          case result
            in Failure[:invalid, errors]
              refuse(request, response, timing: { id:, values: Blog::Constants::EMPTY_HASH, errors: })
            else settle(response, result, DELETED, tasks_path(request))
          end
        end
      end
    end
  end
end
