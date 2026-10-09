# frozen_string_literal: true

module API
  module Actions
    module BulkMessages
      class Tag < Action
        include Deps[endpoint: "endpoints.tag_messages"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
