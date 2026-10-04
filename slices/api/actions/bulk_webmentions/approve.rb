# frozen_string_literal: true

module API
  module Actions
    module BulkWebmentions
      class Approve < Action
        include Deps[endpoint: "endpoints.approve_webmentions"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
