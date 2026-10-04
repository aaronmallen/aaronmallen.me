# frozen_string_literal: true

module API
  module Actions
    module DecisionOptions
      class Update < Action
        include Deps[endpoint: "endpoints.edit_decision_option"]

        def handle(request, response)
          ids = { "id" => record_id(request), "option_id" => number(request.params[:option_id]) }

          answer(response, endpoint.call(body(request, response).merge(ids)))
        end
      end
    end
  end
end
