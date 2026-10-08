# frozen_string_literal: true

require "date"

module Blog
  module Contracts
    class ReviewRangeContract < Contract
      MONTH = Types::ReviewPeriod["month"]
      WEEK_DAYS = 7

      def self.range(period, on)
        return { from: Date.new(on.year, on.month, 1), to: Date.new(on.year, on.month, -1) } if period == MONTH

        monday = on - (on.cwday - 1)
        { from: monday, to: monday + (WEEK_DAYS - 1) }
      end

      params do
        required(:period).value(Types::ReviewPeriod)
        required(:on).value(:date)

        after(:rule_applier) { |result| ReviewRangeContract.range(result[:period], result[:on]) if result.success? }
      end
    end
  end
end
