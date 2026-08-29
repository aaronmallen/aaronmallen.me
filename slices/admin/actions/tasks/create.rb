# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Create < Action
        BLANK = "tasks_page.toasts.blank"
        CAPTURED = "tasks_page.toasts.captured"
        PAST = "tasks_page.toasts.sprint_past"
        UPCOMING = Blog::Types::TaskView["upcoming"]

        include Redirect
        include Deps[
          build_tasks_page: "operations.build_tasks_page",
          capture_task: "tasks.operations.capture_task",
          index_view: "ui.views.tasks.index",
        ]

        def handle(request, response)
          filter = Blog::Types::TaskFilterParam[request.params[:filter]]
          params = Blog::Types::Fields[request.params[:task]]

          case capture_task.call(params, filter:, sprint_on: request.params[:sprint_on])
          in Success[:captured, *] then done(request, response, CAPTURED)
          in Success[:pulled_in | :scheduled, *] then done(request, response, CAPTURED, filter: UPCOMING)
          in Failure(:past) | Failure(:invalid) then done(request, response, PAST)
          in Failure[:invalid, errors] then invalid(request, response, filter, params, errors)
          else halt 500
          end
        end

        private

        def blank(request, response)
          toast(response, BLANK)
          response.redirect_to(tasks_path(request))
        end

        def done(request, response, key, filter: nil)
          toast(response, key)
          response.redirect_to(tasks_path(request, filter:))
        end

        def invalid(request, response, filter, params, errors)
          return blank(request, response) if from_today?(request)

          response.status = 422

          case build_tasks_page.call(tab: filter, params:, errors:)
          in Success(screen) then response.render(index_view, **screen)
          else halt 500
          end
        end
      end
    end
  end
end
