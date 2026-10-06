# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Reopen < Action
        REOPENED = "tasks_page.toasts.reopened"

        include Redirect
        include Deps[reopen_task: "tasks.operations.reopen_task"]

        def handle(request, response)
          settle(response, reopen_task.call(record_id(request)), REOPENED, tasks_path(request))
        end
      end
    end
  end
end
