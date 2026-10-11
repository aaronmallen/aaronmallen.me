# frozen_string_literal: true

module Health
  module Structs
    class Baseline < Data.define(:minutes_asleep, :hrv, :resting_heart_rate)
      HRV_DROP = 5
      RESTING_RISE = 3

      def high_resting?(day) = above?(day.resting_heart_rate, resting_heart_rate, RESTING_RISE)

      def low_hrv?(day) = above?(hrv, day.hrv, HRV_DROP)

      private

      def above?(value, base, margin) = !value.nil? && !base.nil? && value >= base + margin
    end
  end
end
