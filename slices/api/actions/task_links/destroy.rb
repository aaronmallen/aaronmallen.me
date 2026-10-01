# frozen_string_literal: true

module API
  module Actions
    module TaskLinks
      class Destroy < Action
        include Deps[endpoint: "endpoints.unlink_task"]

        def handle(request, response)
          answer(response, endpoint.call(id: record_id(request), other_id: number(request.params[:other_id])))
        end
      end
    end
  end
end
