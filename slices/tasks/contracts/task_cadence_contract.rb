# frozen_string_literal: true

module Tasks
  module Contracts
    class TaskCadenceContract < Blog::Contract
      FIELDS = {
        Blog::Types::TaskCadence["days"] => %i[every],
        Blog::Types::TaskCadence["weeks"] => %i[every weekday starts_on],
        Blog::Types::TaskCadence["month_day"] => %i[day],
        Blog::Types::TaskCadence["month_end"] => [],
        Blog::Types::TaskCadence["month_weekday"] => %i[week weekday],
        Blog::Types::TaskCadence["yearly"] => %i[month day],
      }.freeze
      DAYS = (1..31)
      EVERY = (1..365)
      LEAP_YEAR = 2024
      MONTHS = (1..12)
      WEEKDAYS = (0..6)
      WEEKS = [1, 2, 3, 4, -1].freeze

      params do
        required(:cadence).filled(Blog::Types::TaskCadence)
        optional(:every).maybe(:integer, included_in?: EVERY)
        optional(:weekday).maybe(:integer, included_in?: WEEKDAYS)
        optional(:week).maybe(:integer, included_in?: WEEKS)
        optional(:day).maybe(:integer, included_in?: DAYS)
        optional(:month).maybe(:integer, included_in?: MONTHS)
        optional(:starts_on).maybe(:date)
      end

      rule(:cadence) do
        FIELDS.fetch(value).each { key(it).failure(BLANK) if values[it].nil? }
      end

      rule(:day, :month) do
        month, day = values.values_at(:month, :day)
        key(:day).failure(FORMAT) if month && day && day > Date.new(LEAP_YEAR, month, -1).day
      end
    end
  end
end
