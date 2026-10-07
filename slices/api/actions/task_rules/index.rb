# frozen_string_literal: true

module API
  module Actions
    module TaskRules
      class Index < Action
        include Deps[endpoint: "endpoints.list_task_rules"]

        def handle(_request, response) = answer(response, endpoint.call)
      end
    end
  end
end
