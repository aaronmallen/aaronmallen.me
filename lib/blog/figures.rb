# frozen_string_literal: true

module Blog
  module Figures
    DELIMITER = ","
    DURATION = "%d:%02d"
    GROUPS = /(\d)(?=(\d{3})+\z)/
    MINUTE = 60
    PERCENT = 100
    WORD = /\S+/
    ZERO = 0

    module_function

    def average(total, count) = count.zero? ? ZERO : total / count

    def count(number) = number.to_i.to_s.gsub(GROUPS, "\\1#{DELIMITER}")

    def duration(seconds) = format(DURATION, seconds / MINUTE, seconds % MINUTE)

    def rate(part, whole) = whole.zero? ? 0.0 : (part.to_f / whole).round(1)

    def share(part, whole) = whole.zero? ? ZERO : ((part * PERCENT.to_f) / whole).round

    def words(text) = text.to_s.scan(WORD).size
  end
end
