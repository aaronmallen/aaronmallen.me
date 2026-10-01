# frozen_string_literal: true

module API
  module Actions
    module Tasks
      class Create < Action
        include Deps[endpoint: "endpoints.capture_task"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)), status: CREATED)
      end
    end
  end
end
