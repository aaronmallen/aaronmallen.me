# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Create < Action
        BLANK = "tasks_page.toasts.blank"
        CAPTURED = "tasks_page.toasts.captured"
        FIELDS = %i[list note sprint_on tags title].freeze
        PAST = "tasks_page.toasts.sprint_past"
        UPCOMING = Blog::Types::TaskView["upcoming"]

        include Redirect
        include Deps[
          capture_task: "tasks.operations.capture_task",
          new_view: "ui.views.tasks.new",
        ]

        def handle(request, response)
          params = Blog::Types::Fields[request.params[:task]]
          filter = Blog::Types::TaskFilterParam[params[:list] || request.params[:filter]]

          case capture_task.call(params, filter:, sprint_on: params[:sprint_on])
          in Success[:captured, *] then done(request, response, CAPTURED, filter:)
          in Success[:pulled_in | :scheduled, *] then done(request, response, CAPTURED, filter: UPCOMING)
          in Failure(:past) | Failure(:invalid) then done(request, response, PAST, filter:)
          in Failure[:invalid, errors] then invalid(request, response, params, errors)
          else halt 500
          end
        end

        private

        def blank(request, response)
          toast(response, BLANK)
          response.redirect_to(tasks_path(request))
        end

        def done(request, response, key, filter:)
          toast(response, key)
          response.redirect_to(tasks_path(request, filter:))
        end

        def invalid(request, response, params, errors)
          return blank(request, response) if from_today?(request)

          response.status = 422
          response.render(new_view, errors:, values: FIELDS.to_h { [it, Blog::Types::Text[params[it]]] })
        end
      end
    end
  end
end
