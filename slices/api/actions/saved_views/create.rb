# frozen_string_literal: true

module API
  module Actions
    module SavedViews
      class Create < Action
        include Deps[endpoint: "endpoints.create_saved_view"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)), status: CREATED)
      end
    end
  end
end
