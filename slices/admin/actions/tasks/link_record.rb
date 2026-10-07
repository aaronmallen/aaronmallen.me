# frozen_string_literal: true

module Admin
  module Actions
    module Tasks
      class LinkRecord < Action
        KIND = Blog::Types::RecordKind["task"]
        LINKED = "tasks_page.toasts.record_linked"

        include Redirect
        include RecordLinking
        include Deps[
          build_task_page: "operations.build_task_page",
          link_records: "links.operations.link_records",
          task_view: "ui.views.tasks.show",
        ]

        def handle(request, response) = link(request, response)

        private

        def record_path(request, _id) = tasks_path(request)

        def render_refused(request, response, id, errors)
          case build_task_page.call(id, records: records_query(request, errors))
            in Success(page) then response.render(task_view, **page, **return_to(request))
            in Failure(:not_found) then halt 404
            else halt 500
          end
        end
      end
    end
  end
end
