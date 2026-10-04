# frozen_string_literal: true

module Admin
  module Actions
    module Inbox
      class MarkMessage < Action
        TOASTS = "messages_page.toasts"

        include Deps[mark_message: "contact.operations.mark_message"]

        def handle(request, response)
          status = request.params[:status]

          case mark_message.call(record_id(request), status)
          in Success(_)
            toast(response, "#{TOASTS}.#{status}")
            response.redirect_to(routes.path(:admin_inbox))
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end
      end
    end
  end
end
