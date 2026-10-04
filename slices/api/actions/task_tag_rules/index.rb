# frozen_string_literal: true

module API
  module Actions
    module TaskTagRules
      class Index < Action
        include Deps[endpoint: "endpoints.list_task_tag_rules"]

        def handle(_request, response) = answer(response, endpoint.call)
      end
    end
  end
end
