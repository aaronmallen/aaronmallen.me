# frozen_string_literal: true

module API
  module Actions
    module Tasks
      class Create < Action
        include Deps[endpoint: "endpoints.capture_task"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
