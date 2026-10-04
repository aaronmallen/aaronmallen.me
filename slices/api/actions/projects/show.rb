# frozen_string_literal: true

module API
  module Actions
    module Projects
      class Show < Action
        include Deps[endpoint: "endpoints.read_project"]

        def handle(request, response) = answer(response, endpoint.call(id: record_id(request)))
      end
    end
  end
end
