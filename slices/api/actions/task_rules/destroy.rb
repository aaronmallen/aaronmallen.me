# frozen_string_literal: true

module API
  module Actions
    module TaskRules
      class Destroy < Action
        include Deps[endpoint: "endpoints.delete_task_rule"]

        def handle(request, response) = answer(response, endpoint.call(id: record_id(request)))
      end
    end
  end
end
