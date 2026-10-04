# frozen_string_literal: true

module API
  module Actions
    module Activity
      class Summary < Action
        include Deps[endpoint: "endpoints.summarize_activity"]

        def handle(request, response) = answer(response, endpoint.call(query(request, :from, :to)))
      end
    end
  end
end
