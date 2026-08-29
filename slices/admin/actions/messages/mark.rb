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

          case mark_message.call(record_id(request), status)
          in Success(_)
            marked(request, response, status)
          in Failure(:not_found)
            halt 404
          else halt 500
          end
        end

        private

        def filter(request) = Blog::Types::MessageStatusParam[request.params[:filter]]

        def marked(request, response, status)
          toast(response, TOASTS.fetch(status))
          response.redirect_to(routes.path(:admin_messages, status: filter(request)))
        end
      end
    end
  end
end
