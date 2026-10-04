# frozen_string_literal: true

module API
  module Endpoints
    class SummarizeActivity < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { **Blog::DayWindow::RANGE },
        required: %w[from to],
      }.freeze

      REPLY = Serializers::ActivitySummary.reference

      include Deps[
        activity_commit_totals: "activity.queries.activity_commit_totals",
        activity_counts: "activity.queries.activity_counts",
        activity_counts_by_month: "activity.queries.activity_counts_by_month",
      ]

      def handle(from:, to:)
        case Blog::DayWindow.days(from, to)
        in Success[first, last] if Blog::DayWindow.too_long?(first, last) then too_long
        in Success[first, last] then Success(summary(first, last))
        in Failure(message) then invalid(from: [message], to: [message])
        end
      end

      private

      def summary(from, to)
        counted = {
          from:,
          to:,
          kinds: activity_counts.call(from:, to:),
          months: activity_counts_by_month.call(from:, to:),
          repos: activity_commit_totals.call(from:, to:),
        }

        serialized(Serializers::ActivitySummary, counted)
      end

      def too_long = invalid(from: [Blog::DayWindow::TOO_LONG], to: [Blog::DayWindow::TOO_LONG])
    end
  end
end
