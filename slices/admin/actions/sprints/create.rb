# frozen_string_literal: true

module Admin
  module Actions
    module Sprints
      class Create < Action
        AHEAD = "tasks_page.toasts.sprint_ahead"
        INVALID = "tasks_page.toasts.sprint_invalid"
        PLANNED = "tasks_page.toasts.sprint_planned"
        TAKEN = "tasks_page.toasts.sprint_taken"
        UPCOMING = Blog::Types::TaskView["upcoming"]

        include Deps[plan_sprint: "tasks.operations.plan_sprint"]

        def handle(request, response)
          case plan_sprint.call(request.params[:sprint_on])
          in Success(sprint) then done(response, PLANNED, sprint.sprint_date)
          in Failure[:planned, date] then done(response, TAKEN, date)
          in Failure(:past) then done(response, AHEAD)
          in Failure(:invalid) then done(response, INVALID)
          else halt 500
          end
        end

        private

        def done(response, key, date = nil)
          date ? toast(response, key, date: i18n.l(date, format: :medium)) : toast(response, key)
          response.redirect_to(routes.path(:admin_tasks, filter: UPCOMING))
        end
      end
    end
  end
end
