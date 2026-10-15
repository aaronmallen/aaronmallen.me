# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Destroy < Action
        DELETED = "mail_page.toasts.deleted"
        GMAIL_FAILED = "mail_page.toasts.gmail_failed"

        include Redirect
        include Deps[
          delete_message: "mail.operations.delete_message",
          thread_queries: "mail.repos.thread_queries",
        ]

        def handle(request, response)
          id = record_id(request)

          case delete_message.call(id)
            in Failure(:gmail_failed)
              toast(response, GMAIL_FAILED)
              response.redirect_to(Helpers::MailList.back(routes, Helpers::MailList.from(request.params), thread: id))
            in result then settle(response, result, DELETED, listed(request))
          end
        end
      end
    end
  end
end
