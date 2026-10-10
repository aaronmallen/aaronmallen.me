# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Mark < Action
        TOASTS = Blog::Types::MessageStatus.values.to_h { [it, "messages_page.toasts.#{it}"] }.freeze

        include Deps[mark_message: "contact.operations.mark_message"]

        def handle(request, response)
          status = request.params[:status]

          result = mark_message.call(record_id(request), status)
          settle(response, result, TOASTS.fetch(status), back(request))
        end

        private

        def back(request)
          id = Blog::Types::IdParam[request.params[:open]]
          Helpers::MessageList.back(routes, Helpers::MessageList.from(request.params, :filter), open: id)
        end
      end
    end
  end
end
