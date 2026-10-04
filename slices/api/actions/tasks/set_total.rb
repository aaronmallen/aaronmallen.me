# frozen_string_literal: true

module API
  module Actions
    module Tasks
      class SetTotal < Action
        include Deps[endpoint: "endpoints.set_task_total"]

        def handle(request, response)
          answer(response, endpoint.call(body(request, response).merge("id" => record_id(request))))
        end
      end
    end
  end
end
