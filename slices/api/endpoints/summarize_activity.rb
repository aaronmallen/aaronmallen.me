# frozen_string_literal: true

module API
  module Endpoints
    class SummarizeActivity < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { **Blog::Helpers::DayWindow::RANGE },
        required: %w[from to],
      }.freeze

      REPLY = Serializers::ActivitySummary.reference

      include Deps[activity_queries: "activity.repos.activity_queries"]

      def handle(from:, to:)
        case Blog::Helpers::DayWindow.days(from, to)
          in Success[first, last] if Blog::Helpers::DayWindow.too_long?(first, last) then too_long
          in Success[first, last] then Success(summary(first, last))
          in Failure(message) then invalid(from: [message], to: [message])
        end
      end

      private

      def summary(from, to)
        counted = {
          from:,
          to:,
          kinds: activity_queries.counts(from:, to:),
          months: activity_queries.counts_by_month(from:, to:),
          repos: activity_queries.commit_totals(from:, to:),
        }

        serialized(Serializers::ActivitySummary, counted)
      end

      def too_long = invalid(from: [Blog::Helpers::DayWindow::TOO_LONG], to: [Blog::Helpers::DayWindow::TOO_LONG])
    end
  end
end
