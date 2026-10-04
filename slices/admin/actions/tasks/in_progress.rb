# frozen_string_literal: true

require "json"

module Admin
  module Actions
    module Tasks
      class InProgress < Action
        UNAUTHORIZED = 401

        include Deps[tasks_in_progress: "tasks.queries.tasks_in_progress"]

        config.formats.accept :json

        before :forbid_caching

        def handle(_request, response)
          response.format = :json
          response.body = JSON.generate(rows: tasks_in_progress.call.map { row(it) })
        end

        private

        def require_sign_in(request, _response)
          halt UNAUTHORIZED unless auth_session(request).signed_in?
        end

        def row(task) = { id: task.id, title: task.title, href: routes.path(:admin_complete_task, id: task.id) }
      end
    end
  end
end
