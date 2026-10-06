# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class MarkMessage < Action
        TOASTS = "messages_page.toasts"

        include Deps[mark_message: "contact.operations.mark_message"]

        def handle(request, response)
          status = request.params[:status]

          result = mark_message.call(record_id(request), status)
          settle(response, result, "#{TOASTS}.#{status}", routes.path(:admin_inbox))
        end
      end
    end
  end
end
