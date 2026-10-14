# frozen_string_literal: true

module Admin
  module Actions
    module Performance
      class Show < Action
        include Deps[timing_queries: "performance.repos.timing_queries"]

        def handle(request, response)
          range = Blog::Types::AnalyticsRangeParam[request.params[:range]]
          to = Blog::TimeZone.today
          from = to - (range - 1)

          response.render(
            view, range:, days: timing_queries.days_between(from:, to:), **timing_queries.summary_between(from:, to:),
          )
        end
      end
    end
  end
end
