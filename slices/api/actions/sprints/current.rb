# frozen_string_literal: true

module API
  module Actions
    module Sprints
      class Current < Action
        include Deps[endpoint: "endpoints.read_current_sprint"]

        def handle(_request, response) = answer(response, endpoint.call)
      end
    end
  end
end
