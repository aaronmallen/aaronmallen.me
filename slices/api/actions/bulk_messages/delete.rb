# frozen_string_literal: true

module API
  module Actions
    module BulkMessages
      class Delete < Action
        include Deps[endpoint: "endpoints.delete_messages"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
