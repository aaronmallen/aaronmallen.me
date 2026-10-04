# frozen_string_literal: true

module MCP
  module Tools
    module WeekdayGrid
      DAYS = %i[monday tuesday wednesday thursday friday saturday sunday].freeze
      DESCRIPTION = "weekday_hours gives the visitors in each #{Blog::TimeZone::NAME} hour of each weekday over " \
                    "the last 90 days to today, whatever the range: 24 rows, one per hour from 0, each with a " \
                    "count for monday through sunday, and the from, to and time_zone of the window. A visitor " \
                    "counts once a cell by the daily hash, so one reader on two Mondays at 9 counts twice. ".freeze

      module_function

      def call(weekday_hours, to: Blog::TimeZone.today)
        found = weekday_hours.call(to:)
        hours = found.fetch(:hours).each_with_index.map { |counts, hour| { hour:, **DAYS.zip(counts).to_h } }

        { from: (to - (found.fetch(:days) - 1)).iso8601, to: to.iso8601, time_zone: Blog::TimeZone::NAME, hours: }
      end
    end
  end
end
