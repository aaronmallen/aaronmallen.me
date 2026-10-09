# frozen_string_literal: true

module API
  module Actions
    module BulkMessages
      class Untag < Action
        include Deps[endpoint: "endpoints.untag_messages"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
