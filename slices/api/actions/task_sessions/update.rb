# frozen_string_literal: true

module API
  module Actions
    module TaskSessions
      class Update < Action
        include Deps[endpoint: "endpoints.update_work_session"]

        def handle(request, response)
          ids = { "id" => record_id(request), "session_id" => number(request.params[:session_id]) }

          answer(response, endpoint.call(body(request, response).merge(ids)))
        end
      end
    end
  end
end
