# frozen_string_literal: true

module API
  module Endpoints
    class ListCalendar < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { from: Helpers::DayWindow::DAYS, to: Helpers::DayWindow::DAYS },
        required: %w[from to],
      }.freeze

      REPLY = Helpers::Schema.object(
        {
          from: Helpers::Schema::DAY,
          to: Helpers::Schema::DAY,
          days: Helpers::Schema.list(Serializers::CalendarDay.reference),
        },
      ).freeze

      include Deps[
        calendar_day_queries: "calendar.repos.calendar_day_queries",
        networks: "social_networks.all",
        target_accounts: "social.operations.list_target_accounts",
      ]

      def handle(from:, to:)
        found = Helpers::DayWindow.days(from, to, capped: true).fmap { |first, last| calendar_day_queries.between(from: first, to: last) }

        found.either(->(days) { Success(listed(days)) }, method(:bad_window))
      end

      private

      def listed(days)
        listed = serialized(Serializers::CalendarDay, days, networks:, target_accounts:)

        { from: days.first.date.iso8601, to: days.last.date.iso8601, days: listed }
      end
    end
  end
end
