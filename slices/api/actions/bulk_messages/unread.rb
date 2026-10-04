# frozen_string_literal: true

module API
  module Actions
    module BulkMessages
      class Unread < Action
        include Deps[endpoint: "endpoints.mark_messages_unread"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
