# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Snooze < Inbox::Snooze
        private

        def back(request)
          id = record_id(request)
          "#{routes.path(:admin_messages, **Helpers::MessageList.from(request.params, :filter), open: id)}#read-#{id}"
        end

        def kind(_request) = "message"
      end
    end
  end
end
