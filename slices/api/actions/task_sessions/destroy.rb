# frozen_string_literal: true

module API
  module Actions
    module TaskSessions
      class Destroy < Action
        include Deps[endpoint: "endpoints.delete_work_session"]

        def handle(request, response)
          answer(response, endpoint.call(id: record_id(request), session_id: number(request.params[:session_id])))
        end
      end
    end
  end
end
