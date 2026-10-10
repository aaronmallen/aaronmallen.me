# frozen_string_literal: true

module API
  module Endpoints
    class ListCalendar < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { from: Blog::Helpers::DayWindow::DAYS, to: Blog::Helpers::DayWindow::DAYS },
        required: %w[from to],
      }.freeze

      REPLY = Helpers::Schema.object(
        {
          from: Helpers::Schema::DAY,
          to: Helpers::Schema::DAY,
          days: Helpers::Schema.list(Serializers::CalendarDay.reference),
        },
      ).freeze

      include Deps["repos.calendar_queries", target_accounts: "social.operations.list_target_accounts"]

      def handle(from:, to:)
        found = Blog::Helpers::DayWindow.days(from, to).bind { |first, last| calendar_queries.between(from: first, to: last) }

        found.either(->(days) { Success(listed(days)) }, method(:bad_window))
      end

      private

      def listed(days)
        listed = serialized(Serializers::CalendarDay, days, target_accounts:)

        { from: days.first.date.iso8601, to: days.last.date.iso8601, days: listed }
      end
    end
  end
end
