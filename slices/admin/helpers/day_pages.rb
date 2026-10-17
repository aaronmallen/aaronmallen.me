# frozen_string_literal: true

module Admin
  module Helpers
    module DayPages
      module_function

      def call(counts, day:, to:, size:)
        shown = counts.select { |date, _| date <= day }
        start = (ends(shown, size).first if shown.values.sum > size)

        { start:, older: (start.prev_day if start && shown.keys.min < start), newer: newer(counts, day:, to:, size:) }
      end

      def ends(counts, size)
        seen = 0

        counts.each_with_object([]) do |(date, count), found|
          seen += count
          next if seen < size

          found << date
          seen = 0
        end
      end

      def newer(counts, day:, to:, size:)
        return if day >= to

        later = counts.select { |date, _| date >= day }
        starts = [to, *ends(later, size).map(&:prev_day)].select { it > day }
        return starts.last if starts.last == to || later.keys.min <= starts.last || counts.keys.min < day

        starts[-2]
      end
    end
  end
end
