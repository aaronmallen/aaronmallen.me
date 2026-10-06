# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Start < Action
        STARTED = "tasks_page.toasts.started"
        TODAY = Blog::Types::TaskFilter["today"]

        include Redirect
        include Deps[start_task: "tasks.operations.start_task"]

        def handle(request, response)
          result = start_task.call(record_id(request))
          settle(response, result, STARTED, back_here(request) || tasks_path(request, filter: TODAY))
        end
      end
    end
  end
end
