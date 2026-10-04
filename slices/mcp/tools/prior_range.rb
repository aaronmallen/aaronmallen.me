# frozen_string_literal: true

module MCP
  module Tools
    module PriorRange
      DESCRIPTION = "change sets the range's views against the range of the same length just before it: that " \
                    "range's from, to and views, and percent, the rise or fall in views as a whole percent of its " \
                    "views, null when it had none. "

      module_function

      def call(totals, range, analytics_between)
        to = range.first - 1
        from = to - (range.count - 1)
        before = analytics_between.call(from:, to:).fetch(:totals).fetch(:views)

        { from: from.iso8601, to: to.iso8601, views: before, percent: percent(totals.fetch(:views), before) }
      end

      def percent(views, before) = (Blog::Figures.share(views - before, before) if before.positive?)
    end
  end
end
