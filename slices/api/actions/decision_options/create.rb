# frozen_string_literal: true

module API
  module Actions
    module DecisionOptions
      class Create < Action
        include Deps[endpoint: "endpoints.add_decision_option"]

        def handle(request, response)
          answer(response, endpoint.call(body(request, response).merge("id" => record_id(request))), status: CREATED)
        end
      end
    end
  end
end
