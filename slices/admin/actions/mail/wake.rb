# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Wake < Action
        WOKEN = "mail_page.toasts.woken"

        include Redirect
        include Deps[
          thread_queries: "mail.repos.thread_queries",
          wake_message: "mail.operations.wake_message",
        ]

        def handle(request, response)
          id = record_id(request)
          result = wake_message.call(id)
          halt 422 if result in Failure(:not_snoozed)

          settle(response, result, WOKEN, back_here(request) || listed(request, thread: id))
        end
      end
    end
  end
end
