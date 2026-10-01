# frozen_string_literal: true

module API
  module Actions
    module Sprints
      class Create < Action
        include Deps[endpoint: "endpoints.plan_sprint"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)), status: CREATED)
      end
    end
  end
end
