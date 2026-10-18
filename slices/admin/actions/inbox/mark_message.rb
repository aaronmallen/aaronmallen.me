# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class MarkMessage < Action
        TOASTS = "mail_page.toasts"

        include Deps[change_thread: "mail.operations.change_thread"]

        def handle(request, response)
          status = request.params[:status]

          case change_thread.call(record_id(request), status)
            in Failure(:gmail_failed)
              toast(response, "#{TOASTS}.gmail_failed")
              response.redirect_to(routes.path(:admin_inbox))
            in result then settle(response, result, "#{TOASTS}.#{status}", routes.path(:admin_inbox))
          end
        end
      end
    end
  end
end
