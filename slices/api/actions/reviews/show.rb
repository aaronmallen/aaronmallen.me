# frozen_string_literal: true

module API
  module Actions
    module Reviews
      class Show < Action
        include Deps[endpoint: "endpoints.read_review"]

        def handle(request, response)
          answer(response, endpoint.call(query(request, :period, :day, :focus, :contributor, :agent, :model)))
        end
      end
    end
  end
end
