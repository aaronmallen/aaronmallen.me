# frozen_string_literal: true

require "date"

module Blog
  module ReviewRange
    MONTH = Types::ReviewPeriod["month"]
    WEEK_DAYS = 7

    module_function

    def call(period, on)
      return [Date.new(on.year, on.month, 1), Date.new(on.year, on.month, -1)] if period == MONTH

      monday = on - (on.cwday - 1)
      [monday, monday + (WEEK_DAYS - 1)]
    end
  end
end
