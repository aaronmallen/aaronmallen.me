# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Update < Action
        FIELDS = %i[list note tags title].freeze
        PAST = "tasks_page.toasts.sprint_past"
        SAVED = "tasks_page.toasts.saved"

        include Redirect
        include Deps[
          build_tasks_page: "operations.build_tasks_page",
          index_view: "ui.views.tasks.index",
          save_task: "tasks.operations.save_task",
        ]

        def handle(request, response)
          id = record_id(request)
          tab = task_tab(request)
          params = Blog::Types::Fields[request.params[:task]]

          case save_task.call(id, params)
          in Success(_) then done(request, response, SAVED)
          in Failure(:past) | Failure(:invalid) then done(request, response, PAST)
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then invalid(response, tab, id, params, errors)
          else halt 500
          end
        end

        private

        def done(request, response, key)
          toast(response, key)
          response.redirect_to(tasks_path(request))
        end

        def editing(id, params, errors)
          { errors:, id:, **FIELDS.to_h { [it, Blog::Types::Text[params[it]]] } }
        end

        def invalid(response, tab, id, params, errors)
          response.status = 422

          case build_tasks_page.call(tab:, editing: editing(id, params, errors))
          in Success(screen) then response.render(index_view, **screen)
          else halt 500
          end
        end
      end
    end
  end
end
