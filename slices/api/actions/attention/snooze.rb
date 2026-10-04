# frozen_string_literal: true

module API
  module Actions
    module Attention
      class Snooze < Action
        include Deps[endpoint: "endpoints.snooze_attention"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
