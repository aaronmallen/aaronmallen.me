# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class Link < Action
        LINKED = "tasks_page.toasts.linked"

        include Redirect
        include Deps[
          build_task_page: "operations.build_task_page",
          link_tasks: "tasks.operations.link_tasks",
          task_view: "ui.views.tasks.show",
        ]

        def handle(request, response)
          id = record_id(request)
          params = Blog::Types::Fields[request.params[:link]]

          if request.params[:link_find]
            find(request, response, id, params)
          else
            link(request, response, id, params)
          end
        end

        private

        def find(request, response, id, params)
          response.redirect_to(
            routes.path(
              :admin_task,
              id:, **return_to(request).compact,
              link_kind: Blog::Types::Text[params[:kind]], link_q: Blog::Types::TrimmedText[request.params[:link_q]],
            ),
          )
        end

        def invalid(request, response, id, params, errors)
          case build_task_page.call(id, kind: Blog::Types::Text[params[:kind]], errors:)
            in Success(page)
              response.status = 422
              response.render(task_view, **page, **return_to(request))
            in Failure(:not_found) then halt 404
            else halt 500
          end
        end

        def link(request, response, id, params)
          result = link_tasks.call(id, params)

          case result
            in Failure[:invalid, errors] then invalid(request, response, id, params, errors)
            else settle(response, result, LINKED, tasks_path(request))
          end
        end
      end
    end
  end
end
