# frozen_string_literal: true

module API
  module Actions
    module SavedViews
      class Create < Action
        include Deps[endpoint: "endpoints.create_saved_view"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
