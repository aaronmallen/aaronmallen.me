# frozen_string_literal: true

module Admin
  module Actions
    module Commits
      class Import < Action
        TOASTS = "today_page.toasts"

        include Deps[queue_commit_import: "record.operations.queue_commit_import"]

        def handle(_request, response)
          toast(response, "#{TOASTS}.#{enqueue}")
          response.redirect_to(routes.path(:admin_root))
        end

        private

        def enqueue
          case queue_commit_import.call
          in Failure(:not_configured) then :not_configured
          in Success(_) then :queued
          end
        end
      end
    end
  end
end
