# frozen_string_literal: true

module API
  module Actions
    module Decisions
      class Create < Action
        include Deps[endpoint: "endpoints.open_decision"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)), status: CREATED)
      end
    end
  end
end
