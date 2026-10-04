# frozen_string_literal: true

module API
  module Actions
    module SavedViews
      class Records < Action
        include Deps[endpoint: "endpoints.read_saved_view"]

        def handle(request, response)
          answer(response, endpoint.call(paged_query(request, :continue_to).merge(id: record_id(request))))
        end
      end
    end
  end
end
