# frozen_string_literal: true

module API
  module Actions
    module People
      class Search < Action
        include Deps[endpoint: "endpoints.search_accounts"]

        def handle(request, response) = answer(response, endpoint.call(query(request, :network, :query)))
      end
    end
  end
end
