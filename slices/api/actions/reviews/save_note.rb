# frozen_string_literal: true

module API
  module Actions
    module Reviews
      class SaveNote < Action
        include Deps[endpoint: "endpoints.save_review_note"]

        def handle(request, response) = answer(response, endpoint.call(body(request, response)))
      end
    end
  end
end
