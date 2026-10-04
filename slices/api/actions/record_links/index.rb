# frozen_string_literal: true

module API
  module Actions
    module RecordLinks
      class Index < Action
        include Deps[endpoint: "endpoints.list_links"]

        def handle(request, response)
          answer(response, endpoint.call(kind: request.params[:kind], id: record_id(request)))
        end
      end
    end
  end
end
