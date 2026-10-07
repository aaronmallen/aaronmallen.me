# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class Wake < Action
        WOKEN = "inbox_page.toasts.woken"

        include Deps[wake_inbox_row: "api.operations.wake_inbox_row"]

        def handle(request, response)
          result = wake_inbox_row.call(request.params[:kind], record_id(request))
          halt 422 if result in Failure(:not_snoozed)

          settle(response, result, WOKEN, routes.path(:admin_inbox))
        end
      end
    end
  end
end
