# frozen_string_literal: true

require "dry/monads"

module API
  module Helpers
    module DayWindow
      def self.bounds(noun)
        {
          from: { type: "string", description: "the first day of the #{noun}, as YYYY-MM-DD" }.freeze,
          to: { type: "string", description: "the last day of the #{noun}, as YYYY-MM-DD" }.freeze,
        }.freeze
      end

      BACKWARDS = "from comes after to"
      BAD_DAY = "give from and to as days, such as 2026-01-01"
      DAYS = { type: "string", description: "a day, as YYYY-MM-DD" }.freeze
      PAGING_NOTE = "Give from and to as YYYY-MM-DD; both days sit inside the window. " \
                    "One answer carries about %<page_size>s rows, newest first, rounded out to the end of a day. " \
                    "Past that, partial comes back true and continue_to holds the day to send as to " \
                    "for the next window"
      RANGE = bounds("range")
      WINDOW = bounds("window")

      extend Dry::Monads[:result]

      module_function

      def days(from, to, capped: false)
        first = Blog::TimeZone.parse_day(from)
        last = Blog::TimeZone.parse_day(to)
        return Failure(BAD_DAY) unless first && last
        return Failure(BACKWARDS) if first > last
        if capped && last - first >= Blog::Helpers::DayWindow::LONGEST
          return Failure(Blog::Helpers::DayWindow::TOO_LONG)
        end

        Success([first, last])
      end

      def open_day(value)
        return Success(nil) unless value

        day = Blog::TimeZone.parse_day(value)
        day ? Success(day) : Failure(BAD_DAY)
      end

      def open_days(from, to)
        return days(from, to) if from && to

        open_day(from || to).fmap { from ? [it, nil] : [nil, it] }
      end

      def page(first, last, settings, day:, &)
        found = Blog::Structs::DayCursor.page(first, last, size: size(settings), day:, &)
        return { rows: found.rows, partial: false } unless found.partial?

        { rows: found.rows, partial: true, continue_to: found.continue_to.iso8601 }
      end

      def size(settings) = settings.page_size[:mcp]
    end
  end
end
