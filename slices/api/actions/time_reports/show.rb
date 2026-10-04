# frozen_string_literal: true

module API
  module Actions
    module TimeReports
      class Show < Action
        include Deps[endpoint: "endpoints.read_time_report"]

        def handle(request, response) = answer(response, endpoint.call(query(request, :from, :to, :by)))
      end
    end
  end
end
