# frozen_string_literal: true

module API
  module Actions
    module DecisionComments
      class Destroy < Action
        include Deps[endpoint: "endpoints.delete_decision_comment"]

        def handle(request, response)
          answer(response, endpoint.call(id: record_id(request), comment_id: number(request.params[:comment_id])))
        end
      end
    end
  end
end
