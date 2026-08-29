# frozen_string_literal: true

require "dry/monads"

module MCP
  module Tools
    module DayWindow
      CAP = 200
      DAYS = { type: "string", description: "a day, as YYYY-MM-DD" }.freeze
      PAGING_NOTE = "Give from and to as YYYY-MM-DD; both days sit inside the window. " \
                    "One answer carries about #{CAP} rows, newest first, rounded out to the end of a day. " \
                    "Past that, partial comes back true and continue_to holds the day to send as to " \
                    "for the next window".freeze

      extend Dry::Monads[:result]

      module_function

      def days(from, to)
        first = Blog::TimeZone.parse_day(from)
        last = Blog::TimeZone.parse_day(to)
        return Failure("give from and to as days, such as 2026-01-01") unless first && last
        return Failure("from comes after to") if first > last

        Success([first, last])
      end

      def page(first, last, day:)
        head = yield(first, last, CAP + 1)
        return { rows: head, partial: false } if head.length <= CAP

        boundary = day.call(head[CAP - 1])
        rows = head.take_while { day.call(it) > boundary } + yield(boundary, boundary, nil)
        return { rows:, partial: false } unless boundary > first && yield(first, boundary - 1, 1).any?

        { rows:, partial: true, continue_to: (boundary - 1).iso8601 }
      end
    end
  end
end
