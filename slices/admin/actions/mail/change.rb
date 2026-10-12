# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Change < Action
        GMAIL_FAILED = "mail_page.toasts.gmail_failed"
        TOASTS = "mail_page.toasts"

        include Deps[change_thread: "mail.operations.change_thread"]

        def handle(request, response)
          act = request.params[:act]
          id = record_id(request)
          back = Helpers::MailList.back(routes, Helpers::MailList.from(request.params), thread: id)

          case change_thread.call(id, act)
            in Failure(:gmail_failed)
              toast(response, GMAIL_FAILED)
              response.redirect_to(back)
            in result then settle(response, result, "#{TOASTS}.#{act}", back)
          end
        end
      end
    end
  end
end
