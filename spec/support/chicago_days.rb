# frozen_string_literal: true

module Spec
  module ChicagoDays
    def at(day, hour = 12, minute = 0) = Blog::TimeZone.local_time(day.year, day.month, day.day, hour, minute)

    def days_ago(days) = days_ahead(-days)

    def days_ahead(days)
      now = Time.now
      today = Blog::TimeZone.local_date(now)
      clock = now - Blog::TimeZone.day_start(today)
      start = Blog::TimeZone.day_start(today + days)

      Time.at([start + clock, Blog::TimeZone.day_start(today + days + 1) - 1].min)
    end

    def pin_today = today

    def today = @today ||= Blog::TimeZone.today
  end
end

RSpec.configure do |config|
  config.include Spec::ChicagoDays
end
