# frozen_string_literal: true

module API
  module Actions
    module Search
      class Index < Action
        include Deps[endpoint: "endpoints.search"]

        def handle(request, response) = answer(response, endpoint.call(paged_query(request, :query, :kind)))
      end
    end
  end
end
