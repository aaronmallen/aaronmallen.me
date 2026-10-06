# frozen_string_literal: true

module API
  module Actions
    module Tags
      class Show < Action
        include Deps[endpoint: "endpoints.read_tag"]

        def handle(request, response) = answer(response, endpoint.call(name: request.params[:name]))
      end
    end
  end
end
