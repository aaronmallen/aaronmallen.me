# frozen_string_literal: true

module API
  module Actions
    module Inbox
      class SnoozeAll < Action
        include Deps[endpoint: "endpoints.snooze_inbox"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
