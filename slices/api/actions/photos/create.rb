# frozen_string_literal: true

module API
  module Actions
    module Photos
      class Create < Action
        include Deps[endpoint: "endpoints.upload_photo"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
