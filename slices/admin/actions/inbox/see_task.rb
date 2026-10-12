# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class SeeTask < Action
        SEEN = "inbox_page.toasts.seen"

        include Tasks::Redirect
        include Deps[mark_task_seen: "tasks.operations.mark_task_seen"]

        def handle(request, response)
          result = mark_task_seen.call(record_id(request))

          case result
            in Failure(:unsourced) then halt 404
            else settle(response, result, SEEN, back_here(request) || routes.path(:admin_inbox))
          end
        end
      end
    end
  end
end
