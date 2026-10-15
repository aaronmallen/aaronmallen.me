# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Change < Action
        GMAIL_FAILED = "mail_page.toasts.gmail_failed"
        TOASTS = "mail_page.toasts"

        include Redirect
        include Deps[
          change_thread: "mail.operations.change_thread",
          thread_queries: "mail.repos.thread_queries",
        ]

        def handle(request, response)
          act = request.params[:act]
          id = record_id(request)

          case change_thread.call(id, act)
            in Failure(:gmail_failed)
              toast(response, GMAIL_FAILED)
              response.redirect_to(listed(request, thread: id))
            in result then settle(response, result, "#{TOASTS}.#{act}", listed(request, thread: id))
          end
        end
      end
    end
  end
end
