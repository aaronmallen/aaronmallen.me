# frozen_string_literal: true

module API
  module Actions
    module Tasks
      class Update < Action
        include Deps[endpoint: "endpoints.save_task"]

        def handle(request, response)
          answer(response, endpoint.call(body(request, response).merge("id" => record_id(request))))
        end
      end
    end
  end
end
