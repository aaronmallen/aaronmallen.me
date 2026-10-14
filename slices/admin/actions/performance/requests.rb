# frozen_string_literal: true

module Admin
  module Actions
    module Performance
      class Requests < Action
        include Deps[timing_queries: "performance.repos.timing_queries"]

        def handle(request, response)
          params = request.params
          range = Blog::Types::AnalyticsRangeParam[params[:range]]
          route = text(params[:route])
          verb = text(params[:verb])
          to = Blog::TimeZone.today
          from = to - (range - 1)
          rows = timing_queries.slowest_requests(route:, verb:, from:, to:)
          days = timing_queries.route_days_between(route:, verb:, from:, to:)

          response.render(view, range:, route:, verb:, rows:, days:)
        end

        private

        def text(value) = (value if value.is_a?(String) && !value.empty?)
      end
    end
  end
end
