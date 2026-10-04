# frozen_string_literal: true

module API
  module Actions
    module SavedViews
      class Destroy < Action
        include Deps[endpoint: "endpoints.delete_saved_view"]

        def handle(request, response) = answer(response, endpoint.call(id: record_id(request)))
      end
    end
  end
end
