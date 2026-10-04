# frozen_string_literal: true

module API
  module Actions
    module BulkWebmentions
      class Ignore < Action
        include Deps[endpoint: "endpoints.ignore_webmentions"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
