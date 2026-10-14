# frozen_string_literal: true

module API
  module Endpoints
    class ReadPerformance < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: Helpers::DayWindow::RANGE,
        required: %w[from to],
      }.freeze

      INTEGER = Helpers::Schema::INTEGER
      NUMBER = { type: "number" }.freeze
      STRING = Helpers::Schema::STRING
      TOP = 25

      FIGURES = { count: INTEGER, p50: NUMBER, p95: NUMBER }.freeze
      METRIC = Helpers::Schema.nullable(Helpers::Schema.object(FIGURES))
      SERVER = { **FIGURES, query_count: INTEGER, query_time: NUMBER }.freeze

      REPLY = Helpers::Schema.object(
        {
          from: Helpers::Schema::DAY,
          to: Helpers::Schema::DAY,
          time_zone: STRING,
          routes: Helpers::Schema.list(
            Helpers::Schema.object({ route: Helpers::Schema.nullable(STRING), verb: STRING, **SERVER }),
          ),
          jobs: Helpers::Schema.list(Helpers::Schema.object({ job: STRING, **SERVER })),
          pages: Helpers::Schema.list(
            Helpers::Schema.object(
              { route: STRING, **Performance::Repos::TimingReportQueries::METRICS.to_h { [it, METRIC] } },
            ),
          ),
        },
      ).freeze

      include Deps[timing_report_queries: "performance.repos.timing_report_queries"]

      def handle(from:, to:)
        case Helpers::DayWindow.days(from, to, capped: true)
          in Success[first, last] then Success(report(first..last))
          in Failure(message) then bad_window(message)
        end
      end

      private

      def report(range)
        {
          from: range.first.iso8601,
          to: range.last.iso8601,
          time_zone: Blog::TimeZone::NAME,
          routes: timing_report_queries.routes(range, TOP),
          jobs: timing_report_queries.jobs(range, TOP),
          pages: timing_report_queries.pages(range, TOP),
        }
      end
    end
  end
end
