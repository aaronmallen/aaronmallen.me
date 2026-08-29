# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Schedule < Action
        PAST = "tasks_page.toasts.sprint_past"
        PULLED_IN = "tasks_page.toasts.pulled_in"
        SCHEDULED = "tasks_page.toasts.scheduled"
        UNSCHEDULED = "tasks_page.toasts.unscheduled"
        UPCOMING = Blog::Types::TaskView["upcoming"]

        include Redirect
        include Deps[schedule_task: "tasks.operations.schedule_task"]

        def handle(request, response)
          case schedule_task.call(record_id(request), request.params[:sprint_on])
          in Success[:unscheduled, *] then done(request, response, UNSCHEDULED)
          in Success[:pulled_in, *] then done(request, response, PULLED_IN)
          in Success[:scheduled, _, day] then done(request, response, SCHEDULED, date: i18n.l(day, format: :medium))
          in Failure(:past) | Failure(:invalid) then done(request, response, PAST)
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end

        private

        def done(request, response, key, **)
          toast(response, key, **)
          response.redirect_to(tasks_path(request, filter: UPCOMING))
        end
      end
    end
  end
end
