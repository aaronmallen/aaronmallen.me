# frozen_string_literal: true

module Admin
  module Operations
    class BuildCalendarPage
      MONTH_PATTERN = /\A(\d{4})-(\d{2})\z/
      WEEK = 7

      include Deps[calendar_queries: "api.repos.calendar_queries", task_queries: "tasks.repos.task_queries"]

      def call(month: nil, day: nil, today: Blog::TimeZone.today)
        picked = Blog::Types::DateParam[day]
        first = first_of(picked || month_param(month) || today)
        days = calendar_queries.between(from: grid_start(first), to: grid_end(first)).value!
        shown = days.find { it.date == (picked || chosen(first, today)) }

        { month: first, today:, days:, day: shown, tasks: tasks(shown) }
      end

      private

      def chosen(first, today) = first_of(today) == first ? today : first

      def first_of(date) = Date.new(date.year, date.month)

      def grid_end(first)
        last = first.next_month - 1

        last + (WEEK - last.cwday)
      end

      def grid_start(first) = first - (first.cwday - 1)

      def month_param(value)
        year, month = MONTH_PATTERN.match(value.to_s)&.captures&.map(&:to_i)

        Blog::Types::DateParam[Date.new(year, month)] if year && Date.valid_date?(year, month, 1)
      end

      def tasks(day)
        sprint = day.sprint

        sprint ? task_queries.in_sprint(sprint.id) : Blog::Constants::EMPTY_ARRAY
      end
    end
  end
end
