# frozen_string_literal: true

module API
  module Actions
    module DecisionOptions
      class Destroy < Action
        include Deps[endpoint: "endpoints.delete_decision_option"]

        def handle(request, response)
          answer(response, endpoint.call(id: record_id(request), option_id: number(request.params[:option_id])))
        end
      end
    end
  end
end
