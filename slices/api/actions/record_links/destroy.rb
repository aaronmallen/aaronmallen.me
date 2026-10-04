# frozen_string_literal: true

module API
  module Actions
    module RecordLinks
      class Destroy < Action
        include Deps[endpoint: "endpoints.unlink_records"]

        def handle(request, response)
          params = request.params
          pair = { kind: params[:kind], id: record_id(request), other_kind: params[:other_kind] }

          answer(response, endpoint.call(**pair, other_id: number(params[:other_id])))
        end
      end
    end
  end
end
