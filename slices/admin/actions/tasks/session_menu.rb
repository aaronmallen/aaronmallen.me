# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class SessionMenu < Action
        include Deps[task_timeline_queries: "tasks.repos.task_timeline_queries"]

        def handle(request, response)
          id = record_id(request, :session_id)
          task_id = record_id(request)
          session = task_timeline_queries.entry(task_id, "session", id) || halt(404)

          response.render(view, session:, task_id:, return_to: back_here(request))
        end
      end
    end
  end
end
