# frozen_string_literal: true

module API
  module Actions
    module RecordLinks
      class Create < Action
        include Deps[endpoint: "endpoints.link_records"]

        def handle(request, response)
          side = { "kind" => request.params[:kind], "id" => record_id(request) }

          answer(response, endpoint.call(body(request, response).merge(side)))
        end
      end
    end
  end
end
