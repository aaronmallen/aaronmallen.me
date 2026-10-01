# frozen_string_literal: true

module API
  module Actions
    module Tasks
      class Cancel < Action
        include Deps[endpoint: "endpoints.cancel_task"]

        def handle(request, response) = answer(response, endpoint.call(id: record_id(request)))
      end
    end
  end
end
