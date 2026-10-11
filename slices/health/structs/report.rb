# frozen_string_literal: true

module Health
  module Structs
    Report = Data.define(:from, :to, :days, :workouts, :baseline, :patterns)
  end
end
