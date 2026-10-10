# frozen_string_literal: true

module API
  module Actions
    module TaskComments
      class Create < Action
        include Deps[endpoint: "endpoints.add_task_comment"]

        def handle(request, response)
          answer(response, endpoint.call(body(request, response).merge("id" => record_id(request))))
        end
      end
    end
  end
end
