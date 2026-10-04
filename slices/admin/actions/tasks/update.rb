# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Update < Action
        CLOSED = "tasks_page.toasts.closed"
        FIELDS = %i[list note sprint_on tags title].freeze
        PAST = "tasks_page.toasts.sprint_past"
        SAVED = "tasks_page.toasts.saved"

        include Redirect
        include Deps[
          edit_view: "ui.views.tasks.edit",
          save_task: "tasks.operations.save_task",
          task_by_id: "tasks.queries.task_by_id",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:task]]

          case save_task.call(id, params)
          in Success(_) then done(request, response, SAVED)
          in Failure(:closed) then done(request, response, CLOSED)
          in Failure(:past) | Failure(:invalid) then done(request, response, PAST)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then invalid(request, response, id, params, errors)
          else halt 500
          end
        end

        private

        def done(request, response, key)
          toast(response, key)
          response.redirect_to(tasks_path(request))
        end

        def invalid(request, response, id, params, errors)
          task = task_by_id.call(id) || halt(404)
          values = FIELDS.to_h { [it, Blog::Types::Text[params[it]]] }

          response.status = 422
          response.render(edit_view, task:, errors:, values:, **return_to(request))
        end
      end
    end
  end
end
