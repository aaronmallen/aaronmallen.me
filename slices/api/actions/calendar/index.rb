# frozen_string_literal: true

module API
  module Actions
    module Calendar
      class Index < Action
        include Deps[endpoint: "endpoints.list_calendar"]

        def handle(request, response) = answer(response, endpoint.call(query(request, :from, :to)))
      end
    end
  end
end
