# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Wake < Action
        WOKEN = "messages_page.toasts.woken"

        include Deps[wake_message: "contact.operations.wake_message"]

        def handle(request, response)
          id = record_id(request)
          result = wake_message.call(id)
          halt 422 if result in Failure(:not_snoozed)

          settle(response, result, WOKEN, back(request, id))
        end

        private

        def back(request, id)
          status = Blog::Types::MessageStatusParam[request.params[:filter]]
          "#{routes.path(:admin_messages, status:, open: id)}#read-#{id}"
        end
      end
    end
  end
end
