# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class TagTask < Action
        INVALID = "inbox_page.toasts.tags_invalid"
        TAGGED = "inbox_page.toasts.tagged"

        include Deps[save_task: "tasks.operations.save_task", task_by_id: "tasks.queries.task_by_id"]

        def handle(request, response)
          case save_task.call(*retagged(request))
          in Success(_) then toast(response, TAGGED)
          in Failure[:invalid, _] then toast(response, INVALID)
          else halt 500
          end

          response.redirect_to(routes.path(:admin_inbox))
        end

        private

        def retagged(request)
          task = task_by_id.call(record_id(request)) || halt(404)

          [task.id, { title: task.title, note: task.note, list: nil, tags: request.params[:tags] }]
        end
      end
    end
  end
end
