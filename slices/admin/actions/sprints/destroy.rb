# frozen_string_literal: true

module Admin
  module Actions
    module Sprints
      class Destroy < Action
        DROPPED = "tasks_page.toasts.sprint_dropped"
        STARTED = "tasks_page.toasts.sprint_started"
        UPCOMING = Blog::Types::TaskView["upcoming"]

        include Deps[drop_sprint: "tasks.operations.drop_sprint"]

        def handle(request, response)
          case drop_sprint.call(record_id(request))
          in Success(_) then done(response, DROPPED)
          in Failure(:started) then done(response, STARTED)
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end

        private

        def done(response, key)
          toast(response, key)
          response.redirect_to(routes.path(:admin_tasks, filter: UPCOMING))
        end
      end
    end
  end
end
