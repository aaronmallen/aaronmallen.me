# frozen_string_literal: true

module API
  module Actions
    module Sprints
      class Destroy < Action
        include Deps[endpoint: "endpoints.drop_sprint"]

        def handle(request, response) = answer(response, endpoint.call(id: record_id(request)))
      end
    end
  end
end
