# frozen_string_literal: true

module API
  module Actions
    module People
      class Update < Action
        include Deps[endpoint: "endpoints.update_person"]

        def handle(request, response)
          answer(response, endpoint.call(body(request, response).merge("id" => record_id(request))))
        end
      end
    end
  end
end
