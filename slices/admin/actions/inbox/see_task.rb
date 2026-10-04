# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class SeeTask < Action
        SEEN = "inbox_page.toasts.seen"

        include Deps[mark_task_seen: "tasks.operations.mark_task_seen"]

        def handle(request, response)
          case mark_task_seen.call(record_id(request))
          in Success(_)
            toast(response, SEEN)
            response.redirect_to(routes.path(:admin_inbox))
          in Failure(:not_found | :unsourced)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
