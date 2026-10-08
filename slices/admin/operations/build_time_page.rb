# frozen_string_literal: true

module Admin
  module Operations
    class BuildTimePage
      DEFAULT_RANGE = Blog::Types::RangePreset.values.first

      include Deps[time_report_queries: "tasks.repos.time_report_queries"]

      def call(from: nil, to: nil, by: nil, today: Blog::TimeZone.today)
        last = Blog::Types::DateParam[to] || today
        first = Blog::Types::DateParam[from] || (last - (DEFAULT_RANGE - 1))

        {
          report: time_report_queries.report(from: [first, last].min, to: last, by: Blog::Types::TimeGroupingParam[by]),
          today:,
        }
      end
    end
  end
end
