# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Mark < Action
        TOASTS = {
          Blog::Types::MessageStatus["read"] => "messages_page.toasts.read",
          Blog::Types::MessageStatus["spam"] => "messages_page.toasts.spam",
          Blog::Types::MessageStatus["unread"] => "messages_page.toasts.unread",
        }.freeze

        include Deps[mark_message: "contact.operations.mark_message"]

        def handle(request, response)
          status = request.params[:status]

          result = mark_message.call(record_id(request), status)
          settle(response, result, TOASTS.fetch(status), back(request))
        end

        private

        def back(request)
          id = Blog::Types::IdParam[request.params[:open]]
          path = routes.path(:admin_messages, status: filter(request), **({ open: id } if id))

          id ? "#{path}#read-#{id}" : path
        end

        def filter(request) = Blog::Types::MessageStatusParam[request.params[:filter]]
      end
    end
  end
end
