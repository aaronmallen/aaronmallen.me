# frozen_string_literal: true

module API
  module Actions
    module TaskComments
      class Destroy < Action
        include Deps[endpoint: "endpoints.delete_task_comment"]

        def handle(request, response)
          answer(response, endpoint.call(id: record_id(request), comment_id: number(request.params[:comment_id])))
        end
      end
    end
  end
end
