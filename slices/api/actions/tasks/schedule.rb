# frozen_string_literal: true

module API
  module Actions
    module Tasks
      class Schedule < Action
        include Deps[endpoint: "endpoints.schedule_task"]

        def handle(request, response)
          answer(response, endpoint.call(body(request, response).merge("id" => record_id(request))))
        end
      end
    end
  end
end
