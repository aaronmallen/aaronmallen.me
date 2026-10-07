# frozen_string_literal: true

module API
  module Actions
    module Inbox
      class Wake < Action
        include Deps[endpoint: "endpoints.wake_inbox_row"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
