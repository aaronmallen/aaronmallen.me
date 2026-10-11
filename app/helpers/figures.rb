# frozen_string_literal: true

module Blog
  module Helpers
    module Figures
      DELIMITER = ","
      DURATION = "%d:%02d"
      GROUPS = /(\d)(?=(\d{3})+\z)/
      HOUR = 3600
      HOURS = "%dh %02dm"
      KILO = 1024
      MINUTE = 60
      MINUTES = "%dm"
      PERCENT = 100
      PRECISE_BELOW = 10
      UNITS = %w[B KB MB GB TB].freeze
      WORD = /\S+/
      ZERO = 0

      module_function

      def average(total, count) = count.zero? ? ZERO : total / count

      def count(number) = number.to_i.to_s.gsub(GROUPS, "\\1#{DELIMITER}")

      def duration(seconds) = format(DURATION, seconds / MINUTE, seconds % MINUTE)

      def hours(seconds)
        hours, rest = seconds.divmod(HOUR)

        hours.zero? ? format(MINUTES, rest / MINUTE) : format(HOURS, hours, rest / MINUTE)
      end

      def minutes(count) = hours(count * MINUTE)

      def rate(part, whole) = whole.zero? ? 0.0 : (part.to_f / whole).round(1)

      def share(part, whole) = whole.zero? ? ZERO : ((part * PERCENT.to_f) / whole).round

      def size(bytes)
        power = bytes < KILO ? 0 : [Math.log(bytes, KILO).floor, UNITS.size - 1].min
        value = bytes.fdiv(KILO**power)

        "#{power > 1 && value < PRECISE_BELOW ? value.round(1) : value.round} #{UNITS[power]}"
      end

      def words(text) = text.to_s.scan(WORD).size
    end
  end
end
