# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Link < Action
        LINKED = "tasks_page.toasts.linked"

        include Redirect
        include Deps[
          build_tasks_page: "operations.build_tasks_page",
          index_view: "ui.views.tasks.index",
          link_tasks: "tasks.operations.link_tasks",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:link]]

          case link_tasks.call(id, params)
          in Success(_)
            toast(response, LINKED)
            response.redirect_to(tasks_path(request))
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then invalid(request, response, id, params, errors)
          else halt 500
          end
        end

        private

        def invalid(request, response, id, params, errors)
          response.status = 422
          linking = { errors:, id:, kind: Blog::Types::Text[params[:kind]] }

          case build_tasks_page.call(tab: task_tab(request), linking:)
          in Success(screen) then response.render(index_view, **screen)
          else halt 500
          end
        end
      end
    end
  end
end
