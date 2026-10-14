# frozen_string_literal: true

module Tasks
  module Operations
    class NextCadenceDate
      WEEK = 7

      def call(cadence, after)
        case cadence.fetch(:cadence)
          when "days" then after + cadence.fetch(:every)
          when "weeks" then weekly(cadence, after)
          when "yearly" then yearly(*cadence.values_at(:month, :day), after)
          else monthly(after) { in_month(cadence, it) }
        end
      end

      private

      def in_month(cadence, month)
        case cadence.fetch(:cadence)
          when "month_day" then on_day(month.year, month.month, cadence.fetch(:day))
          when "month_end" then last_day(month.year, month.month)
          else nth_weekday(month, *cadence.values_at(:week, :weekday))
        end
      end

      def last_day(year, month) = Date.new(year, month, -1)

      def last_weekday(last, weekday) = last - ((last.wday - weekday) % WEEK)

      def monthly(after)
        date = yield(after)

        date > after ? date : yield(after.next_month)
      end

      def nth_weekday(month, week, weekday)
        return last_weekday(last_day(month.year, month.month), weekday) if week.negative?

        first = month - month.day + 1
        first + ((weekday - first.wday) % WEEK) + ((week - 1) * WEEK)
      end

      def on_day(year, month, day) = Date.new(year, month, [day, last_day(year, month).day].min)

      def weekly(cadence, after)
        start = cadence.fetch(:starts_on)
        first = start + ((cadence.fetch(:weekday) - start.wday) % WEEK)
        return first if first > after

        span = cadence.fetch(:every) * WEEK
        first + ((((after - first).to_i / span) + 1) * span)
      end

      def yearly(month, day, after)
        date = on_day(after.year, month, day)

        date > after ? date : on_day(after.year + 1, month, day)
      end
    end
  end
end
