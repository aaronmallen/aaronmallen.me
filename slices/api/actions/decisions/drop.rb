# frozen_string_literal: true

module API
  module Actions
    module Decisions
      class Drop < Action
        include Deps[endpoint: "endpoints.drop_decision"]

        def handle(request, response)
          answer(response, endpoint.call(body(request, response).merge("id" => record_id(request))))
        end
      end
    end
  end
end
