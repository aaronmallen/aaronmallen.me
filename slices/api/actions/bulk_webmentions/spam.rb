# frozen_string_literal: true

module API
  module Actions
    module BulkWebmentions
      class Spam < Action
        include Deps[endpoint: "endpoints.mark_webmentions_spam"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
