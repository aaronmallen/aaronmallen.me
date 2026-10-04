# frozen_string_literal: true

module API
  module Actions
    module SavedViews
      class Index < Action
        include Deps[endpoint: "endpoints.list_saved_views"]

        def handle(request, response) = answer(response, endpoint.call(query(request, :screen)))
      end
    end
  end
end
