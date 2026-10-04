# frozen_string_literal: true

module API
  module Actions
    module BulkTasks
      class Untag < Action
        include Deps[endpoint: "endpoints.untag_tasks"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
