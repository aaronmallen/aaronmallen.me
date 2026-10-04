# frozen_string_literal: true

require "date"
require "time"
require "tzinfo"

module Blog
  module TimeZone
    DAY_PATTERN = /\A(\d{4})-(\d{2})-(\d{2})\z/
    INPUT_FORMAT = "%Y-%m-%dT%H:%M"
    INPUT_PATTERN = /\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::\d{2}(?:\.\d+)?)?\z/
    NAME = "America/Chicago"
    ZONE = TZInfo::Timezone.get(NAME)

    module_function

    def day_start(date) = local_time(date.year, date.month, date.day)

    def input_value(time) = local(time).strftime(INPUT_FORMAT)

    def local(time) = ZONE.to_local(time)

    def local_time(year, month, day, hour = 0, minute = 0)
      ZONE.local_time(year, month, day, hour, minute, 0, 0, true)
    end

    def on_day(time, date)
      clock = local(time)

      local_time(date.year, date.month, date.day, clock.hour, clock.min)
    end

    def parse_day(value)
      parts = DAY_PATTERN.match(value.to_s)&.captures&.map(&:to_i)
      Date.new(*parts) if parts && Date.valid_date?(*parts)
    end

    def parse_input(value)
      parts = INPUT_PATTERN.match(value.to_s)&.captures&.map(&:to_i)
      local_time(*parts) if parts && valid_clock?(*parts)
    end

    def parse_time(value)
      text = value.to_s
      day = parse_day(text)
      return day_start(day) if day

      parse_input(text) || Time.iso8601(text)
    rescue ArgumentError, TZInfo::PeriodNotFound
      nil
    end

    def today(time = Time.now) = local(time).to_date

    def valid_clock?(year, month, day, hour, minute) = Date.valid_date?(year, month, day) && hour < 24 && minute < 60
  end
end
