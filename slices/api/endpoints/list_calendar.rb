# frozen_string_literal: true

module API
  module Endpoints
    class ListCalendar < Endpoint
      SCHEMA = {
        additionalProperties: false,
        properties: { from: Blog::DayWindow::DAYS, to: Blog::DayWindow::DAYS },
        required: %w[from to],
      }.freeze

      REPLY = Schema.object(
        { from: Schema::DAY, to: Schema::DAY, days: Schema.list(Serializers::CalendarDay.reference) },
      ).freeze

      include Deps["repos.calendar_queries"]

      def handle(from:, to:)
        found = Blog::DayWindow.days(from, to).bind { |first, last| calendar_queries.between(from: first, to: last) }

        found.either(->(days) { Success(listed(days)) }, ->(message) { invalid(from: [message], to: [message]) })
      end

      private

      def listed(days)
        { from: days.first.date.iso8601, to: days.last.date.iso8601, days: serialized(Serializers::CalendarDay, days) }
      end
    end
  end
end
