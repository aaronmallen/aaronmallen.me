# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class LinkRecord < LinkRecordAction
        KIND = Blog::Types::RecordKind["task"]
        LINKED = "tasks_page.toasts.record_linked"

        include Redirect
        include Deps[
          build_task_page: "operations.build_task_page",
          task_view: "ui.views.tasks.show",
        ]

        private

        def record_path(request, _id) = tasks_path(request)

        def render_refused(request, response, id, errors)
          case build_task_page.call(id, records: records_query(request, errors))
            in Success(page) then unprocessable(response, task_view, **page, **return_to(request))
            in Failure(:not_found) then halt :not_found
          end
        end
      end
    end
  end
end
