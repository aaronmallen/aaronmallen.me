# frozen_string_literal: true

module Admin
  module Actions
    module Messages
      class Snooze < Inbox::Snooze
        private

        def back(request)
          id = record_id(request)
          Helpers::MessageList.back(routes, Helpers::MessageList.from(request.params, :filter), open: id)
        end

        def kind(_request) = "message"
      end
    end
  end
end
