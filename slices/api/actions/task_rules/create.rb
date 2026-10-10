# frozen_string_literal: true

module API
  module Actions
    module TaskRules
      class Create < Action
        include Deps[endpoint: "endpoints.create_task_rule"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
