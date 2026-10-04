# frozen_string_literal: true

module API
  module Actions
    module Issues
      class Sync < Action
        include Deps[endpoint: "endpoints.sync_issues"]

        def handle(_request, response) = answer(response, endpoint.call)
      end
    end
  end
end
