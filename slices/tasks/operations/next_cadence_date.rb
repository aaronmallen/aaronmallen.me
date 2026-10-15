# frozen_string_literal: true

module Tasks
  module Operations
    class NextCadenceDate
      DAYS = Blog::Types::TaskCadence["days"]
      MONTH_DAY = Blog::Types::TaskCadence["month_day"]
      MONTH_END = Blog::Types::TaskCadence["month_end"]
      MONTH_WEEKDAY = Blog::Types::TaskCadence["month_weekday"]
      MONTHLY = [MONTH_DAY, MONTH_END, MONTH_WEEKDAY].freeze
      WEEK = 7
      WEEKS = Blog::Types::TaskCadence["weeks"]
      YEARLY = Blog::Types::TaskCadence["yearly"]

      def call(cadence, after)
        case cadence.fetch(:cadence)
          when DAYS then after + cadence.fetch(:every)
          when WEEKS then weekly(cadence, after)
          when YEARLY then yearly(*cadence.values_at(:month, :day), after)
          when *MONTHLY then monthly(after) { in_month(cadence, it) }
          else raise ArgumentError, "no cadence for #{cadence.fetch(:cadence)}"
        end
      end

      private

      def in_month(cadence, month)
        case cadence.fetch(:cadence)
          when MONTH_DAY then on_day(month.year, month.month, cadence.fetch(:day))
          when MONTH_END then last_day(month.year, month.month)
          when MONTH_WEEKDAY then nth_weekday(month, *cadence.values_at(:week, :weekday))
          else raise ArgumentError, "no monthly cadence for #{cadence.fetch(:cadence)}"
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
