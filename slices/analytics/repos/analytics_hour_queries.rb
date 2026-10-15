# frozen_string_literal: true

module Analytics
  module Repos
    class AnalyticsHourQueries < Blog::DB::Repo
      HOURS = (0..23)
      WEEKDAYS = (1..7)

      include Deps[
        event_queries: "repos.analytics_event_queries",
        rollup_queries: "repos.analytics_rollup_queries",
      ]

      def weekday_hours(to: Blog::TimeZone.today)
        from = event_queries.retention_start(to)
        counts = analytics_rollup_hours.between(from, to).visitors_by_weekday_hour
        rollup_queries.unrolled_summaries(from:, to:).each { add_hours(counts, it) }

        { days: AnalyticsEventQueries::RETENTION_DAYS, hours: HOURS.map { |hour| weekday_counts(counts, hour) } }
      end

      private

      def add_hours(counts, summary)
        summary.hours.each do |row|
          key = [summary.day.cwday, row.fetch(:hour)]
          counts[key] = counts.fetch(key, 0) + row.fetch(:visitors)
        end
      end

      def weekday_counts(counts, hour) = WEEKDAYS.map { |weekday| counts.fetch([weekday, hour], 0) }
    end
  end
end
