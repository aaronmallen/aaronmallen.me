# frozen_string_literal: true

module MCP
  module Tools
    module WeekdayGrid
      DAYS = %i[monday tuesday wednesday thursday friday saturday sunday].freeze
      DESCRIPTION = "weekday_hours gives the visitors in each #{Blog::TimeZone::NAME} hour of each weekday over " \
                    "the last #{Analytics::Repos::AnalyticsEventQueries::RETENTION_DAYS} days to today, whatever " \
                    "the range: 24 rows, one per hour from 0, each with a count for monday through sunday, and " \
                    "the from, to and time_zone of the window. A visitor counts once a cell by the daily hash, so " \
                    "one reader on two Mondays at 9 counts twice. ".freeze

      module_function

      def call(event_queries, to: Blog::TimeZone.today)
        found = event_queries.weekday_hours(to:)
        hours = found.fetch(:hours).each_with_index.map { |counts, hour| { hour:, **DAYS.zip(counts).to_h } }
        from = event_queries.retention_start(to)

        { from: from.iso8601, to: to.iso8601, time_zone: Blog::TimeZone::NAME, hours: }
      end
    end
  end
end
