# frozen_string_literal: true

module Analytics
  module Queries
    class WeekdayHours
      HOURS = (0..23)
      WEEKDAYS = (1..7)

      include Deps[event_repo: "repos.analytics_event_repo"]

      def call(to: Blog::TimeZone.today)
        counts = event_repo.visitors_by_weekday_hour(from: to - (days - 1), to:)

        { days:, hours: HOURS.map { |hour| WEEKDAYS.map { |weekday| counts.fetch([weekday, hour], 0) } } }
      end

      private

      def days = Operations::PruneAnalyticsEvents::RETENTION_DAYS
    end
  end
end
