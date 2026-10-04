# frozen_string_literal: true

module API
  module Actions
    module Tasks
      class See < Action
        include Deps[endpoint: "endpoints.mark_task_seen"]

        def handle(request, response) = answer(response, endpoint.call(id: record_id(request)))
      end
    end
  end
end
