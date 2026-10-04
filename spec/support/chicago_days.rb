# frozen_string_literal: true

module Spec
  module ChicagoDays
    def days_ago(days) = days_ahead(-days)

    def days_ahead(days)
      now = Time.now
      today = Blog::TimeZone.today(now)
      clock = now - Blog::TimeZone.day_start(today)
      start = Blog::TimeZone.day_start(today + days)

      Time.at([start + clock, Blog::TimeZone.day_start(today + days + 1) - 1].min)
    end
  end
end

RSpec.configure do |config|
  config.include Spec::ChicagoDays
end
