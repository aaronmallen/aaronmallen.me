# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class LinkRecord < Action
        KIND = Blog::Types::RecordKind["task"]
        LINKED = "tasks_page.toasts.record_linked"

        include Redirect
        include Deps[
          build_task_page: "operations.build_task_page",
          link_records: "links.operations.link_records",
          task_view: "ui.views.tasks.show",
        ]

        def handle(request, response)
          id = record_id(request)

          case link_records.call(KIND, id, Blog::Types::Fields[request.params[:record]])
          in Success(_)
            toast(response, LINKED)
            response.redirect_to(tasks_path(request))
          in Failure(:not_found) then halt 404
          in Failure[:invalid, errors] then invalid(request, response, id, errors)
          else halt 500
          end
        end

        private

        def invalid(request, response, id, errors)
          case build_task_page.call(id, records: { query: request.params[:record_q], errors: })
          in Success(page)
            response.status = 422
            response.render(task_view, **page, **return_to(request))
          in Failure(:not_found) then halt 404
          else halt 500
          end
        end
      end
    end
  end
end
