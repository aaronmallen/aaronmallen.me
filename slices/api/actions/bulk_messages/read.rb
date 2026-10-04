# frozen_string_literal: true

module API
  module Actions
    module BulkMessages
      class Read < Action
        include Deps[endpoint: "endpoints.mark_messages_read"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
