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
          result = drop_sprint.call(record_id(request))

          case result
            in Failure(:started) then done(response, STARTED)
            else settle(response, result, DROPPED, upcoming_path)
          end
        end

        private

        def done(response, key)
          toast(response, key)
          response.redirect_to(upcoming_path)
        end

        def upcoming_path = routes.path(:admin_tasks, filter: UPCOMING)
      end
    end
  end
end
