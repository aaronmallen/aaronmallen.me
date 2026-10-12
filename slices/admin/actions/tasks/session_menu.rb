# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class SessionMenu < Action
        include Deps[task_queries: "tasks.repos.task_queries"]

        def handle(request, response)
          id = Blog::Types::IdParam[request.params[:session_id]] || halt(404)
          task_id = record_id(request)
          session = task_queries.timeline(task_id).find { it.session? && it.source_id == id } || halt(404)

          response.render(view, session:, task_id:, return_to: back_here(request))
        end
      end
    end
  end
end
