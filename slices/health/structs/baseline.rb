# frozen_string_literal: true

module Health
  module Structs
    Baseline = Data.define(:minutes_asleep, :hrv, :resting_heart_rate)
  end
end
