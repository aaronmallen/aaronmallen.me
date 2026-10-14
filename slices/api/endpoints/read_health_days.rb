# frozen_string_literal: true

module API
  module Endpoints
    class ReadHealthDays < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { **Helpers::DayWindow::RANGE },
        required: %w[from to],
      }.freeze

      REPLY = Serializers::HealthReport.reference

      include Deps[health_queries: "health.repos.health_queries"]

      def handle(from:, to:)
        case Helpers::DayWindow.days(from, to)
          in Success[first, last] if Blog::Helpers::DayWindow.too_long?(first, last)
            bad_window(Blog::Helpers::DayWindow::TOO_LONG)
          in Success[first, last] then Success(report(first, last))
          in Failure(message) then bad_window(message)
        end
      end

      private

      def report(from, to) = serialized(Serializers::HealthReport, health_queries.report(from:, to:))
    end
  end
end
