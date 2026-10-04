# frozen_string_literal: true

module API
  module Actions
    module PostEdits
      class Update < Action
        include Deps[endpoint: "endpoints.update_post_edit_note"]

        def handle(request, response)
          ids = { "id" => record_id(request), "edit_id" => number(request.params[:edit_id]) }

          answer(response, endpoint.call(body(request, response).merge(ids)))
        end
      end
    end
  end
end
