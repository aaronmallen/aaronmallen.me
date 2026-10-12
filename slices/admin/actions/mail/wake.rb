# frozen_string_literal: true

module Admin
  module Actions
    module Mail
      class Wake < Action
        WOKEN = "mail_page.toasts.woken"

        include Deps[wake_message: "mail.operations.wake_message"]

        def handle(request, response)
          id = record_id(request)
          result = wake_message.call(id)
          halt 422 if result in Failure(:not_snoozed)

          list = Helpers::MailList.from(request.params)
          back = back_here(request) || Helpers::MailList.back(routes, list, thread: id)
          settle(response, result, WOKEN, back)
        end
      end
    end
  end
end
