# frozen_string_literal: true

module API
  module Actions
    module People
      class Destroy < Action
        include Deps[endpoint: "endpoints.delete_person"]

        def handle(request, response) = answer(response, endpoint.call(id: record_id(request)))
      end
    end
  end
end
