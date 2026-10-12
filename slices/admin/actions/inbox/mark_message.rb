# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class MarkMessage < Action
        TOASTS = "mail_page.toasts"

        include Deps[mark_message: "mail.operations.mark_message"]

        def handle(request, response)
          status = request.params[:status]

          case mark_message.call(record_id(request), status)
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
