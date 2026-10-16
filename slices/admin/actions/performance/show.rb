# frozen_string_literal: true

module Admin
  module Actions
    module Performance
      class Show < Action
        BROWSER = { load_p50: %i[load p50], load_p95: %i[load p95], lcp_p50: %i[lcp p50], lcp_p95: %i[lcp p95] }.freeze
        BROWSER_VERB = "GET"
        QUERIES = %i[query_count query_time].freeze

        include Deps[timing_report_queries: "performance.repos.timing_report_queries"]

        def handle(request, response)
          range = Blog::Types::AnalyticsRangeParam[request.params[:range]]
          to = Blog::TimeZone.today
          days = (to - (range - 1))..to
          jobs = averaged(timing_report_queries.jobs(days))

          response.render(view, range:, days: timing_report_queries.days(days), jobs:, routes: route_rows(days))
        end

        private

        def averaged(rows) = rows.map { |row| row.merge(QUERIES.to_h { [it, row.fetch(it).fdiv(row.fetch(:count))] }) }

        def browser(page) = BROWSER.transform_values { page.dig(*it) }

        def route_rows(days)
          pages = timing_report_queries.pages(days).to_h { |page| [page[:route], browser(page)] }

          averaged(timing_report_queries.routes(days)).map do |route|
            route.merge(browser: (pages[route[:route]] if route[:verb] == BROWSER_VERB))
          end
        end
      end
    end
  end
end
