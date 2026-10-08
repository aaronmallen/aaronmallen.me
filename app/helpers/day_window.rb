# frozen_string_literal: true

require "dry/monads"

module Blog
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
      CAP = 100
      DAYS = { type: "string", description: "a day, as YYYY-MM-DD" }.freeze
      LONGEST = 366
      PAGING_NOTE = "Give from and to as YYYY-MM-DD; both days sit inside the window. " \
                    "One answer carries about #{CAP} rows, newest first, rounded out to the end of a day. " \
                    "Past that, partial comes back true and continue_to holds the day to send as to " \
                    "for the next window".freeze
      RANGE = bounds("range")
      TOO_LONG = "give a range of #{LONGEST} days or fewer".freeze
      WINDOW = bounds("window")

      extend Dry::Monads[:result]

      module_function

      def days(from, to)
        first = TimeZone.parse_day(from)
        last = TimeZone.parse_day(to)
        return Failure(BAD_DAY) unless first && last
        return Failure(BACKWARDS) if first > last

        Success([first, last])
      end

      def open_day(value)
        return Success(nil) unless value

        day = TimeZone.parse_day(value)
        day ? Success(day) : Failure(BAD_DAY)
      end

      def open_days(from, to)
        return days(from, to) if from && to

        open_day(from || to).fmap { from ? [it, nil] : [nil, it] }
      end

      def page(first, last, day:, &)
        found = Structs::DayCursor.page(first, last, size: CAP, day:, &)
        return { rows: found.rows, partial: false } unless found.partial?

        { rows: found.rows, partial: true, continue_to: found.continue_to.iso8601 }
      end

      def too_long?(first, last) = last - first >= LONGEST
    end
  end
end
