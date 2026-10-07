# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Tasks
      class InProgress < Action
        ROUTES = {
          Blog::Types::TaskAct["complete"] => :admin_complete_task,
          Blog::Types::TaskAct["pause"] => :admin_stop_task,
        }.freeze
        UNAUTHORIZED = 401

        include Deps[task_queries: "tasks.repos.task_queries"]

        config.formats.accept :json

        before :forbid_caching

        def handle(request, response)
          route = ROUTES.fetch(Blog::Types::TaskActParam[request.params[:act]])

          response.format = :json
          response.body = JSON.generate(rows: task_queries.in_progress.map { row(it, route) })
        end

        private

        def require_sign_in(request, _response)
          halt UNAUTHORIZED unless auth_session(request).signed_in?
        end

        def row(task, route) = { id: task.id, title: task.title, href: routes.path(route, id: task.id) }
      end
    end
  end
end
