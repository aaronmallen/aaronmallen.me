# frozen_string_literal: true

module API
  module Endpoints
    class ReadTimeReport < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: {
          from: Blog::DayWindow::DAYS,
          to: Blog::DayWindow::DAYS,
          by: {
            type: "string",
            enum: Blog::Types::TimeGrouping.values,
            description: "sum the time by tag, project or day; tag when left out",
          },
        },
        required: %w[from to],
      }.freeze

      REPLY = Serializers::TimeReport.reference

      include Deps[time_report_queries: "tasks.repos.time_report_queries"]

      def handle(from:, to:, by: Blog::Types::TimeGrouping.values.first)
        case Blog::DayWindow.days(from, to)
          in Success[first, last] then Success(report(first, last, by))
          in Failure(message) then invalid(from: [message], to: [message])
        end
      end

      private

      def report(first, last, by)
        serialized(Serializers::TimeReport, time_report_queries.report(from: first, to: last, by:))
      end
    end
  end
end
