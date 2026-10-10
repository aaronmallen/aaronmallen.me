# frozen_string_literal: true

module API
  module Actions
    module People
      class Create < Action
        include Deps[endpoint: "endpoints.create_person"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
