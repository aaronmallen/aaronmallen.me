# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Snooze < Inbox::Snooze
        private

        def back(request)
          id = record_id(request)
          "#{routes.path(:admin_messages, status: filter(request), open: id)}#read-#{id}"
        end

        def filter(request) = Blog::Types::MessageStatusParam[request.params[:filter]]

        def kind(_request) = "message"
      end
    end
  end
end
