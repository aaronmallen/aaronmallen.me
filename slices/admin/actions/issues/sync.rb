# frozen_string_literal: true

module Admin
  module Actions
    module Issues
      class Sync < Action
        EXTERNAL = Blog::Types::TaskTab["external"]
        TOASTS = "tasks_page.toasts.issue_sync"

        include Deps[queue_issue_sync: "tasks.operations.queue_issue_sync"]

        def handle(_request, response)
          toast(response, "#{TOASTS}.#{enqueue}")
          response.redirect_to(routes.path(:admin_tasks, filter: EXTERNAL))
        end

        private

        def enqueue
          case queue_issue_sync.call
          in Failure(:not_configured) then :not_configured
          in Success(_) then :queued
          end
        end
      end
    end
  end
end
