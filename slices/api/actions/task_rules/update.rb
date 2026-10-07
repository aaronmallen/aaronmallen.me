# frozen_string_literal: true

module API
  module Actions
    module TaskRules
      class Update < Action
        include Deps[endpoint: "endpoints.update_task_rule"]

        def handle(request, response)
          answer(response, endpoint.call(body(request, response).merge("id" => record_id(request))))
        end
      end
    end
  end
end
