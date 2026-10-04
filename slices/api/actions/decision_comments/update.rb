# frozen_string_literal: true

module API
  module Actions
    module DecisionComments
      class Update < Action
        include Deps[endpoint: "endpoints.edit_decision_comment"]

        def handle(request, response)
          ids = { "id" => record_id(request), "comment_id" => number(request.params[:comment_id]) }

          answer(response, endpoint.call(body(request, response).merge(ids)))
        end
      end
    end
  end
end
