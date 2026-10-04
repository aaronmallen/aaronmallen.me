# frozen_string_literal: true

module API
  module Actions
    module TaskTagRules
      class Create < Action
        include Deps[endpoint: "endpoints.create_task_tag_rule"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)), status: CREATED)
      end
    end
  end
end
