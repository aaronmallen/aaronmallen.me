# frozen_string_literal: true

module Health
  module Structs
    class Patterns < Data.define(:short_nights, :morning_workouts, :late_commits, :resting_heart_rate)
      FOCUS = %i[focus_minutes].freeze
      MINIMUM_DAYS = 3
      NIGHT = %i[minutes_asleep hrv].freeze
      NOON = 12
      RESTING = %i[resting_heart_rate].freeze
      SHORT_NIGHT = 360
      WEEK = 7

      class << self
        def from(days, workouts)
          weekdays = days.select { it.weekday? && it.health? }

          new(
            short_nights: compare(by_night(weekdays), FOCUS),
            morning_workouts: compare(by_workout(weekdays, workouts), FOCUS),
            late_commits: compare(after_late_commits(days), NIGHT),
            resting_heart_rate: compare(by_week(days), RESTING),
          )
        end

        private

        def after_late_commits(days)
          pairs = days.each_cons(2).select { |_, day| day.health? }

          pairs.partition { |before, _| before.late_commits.positive? }.map { it.map(&:last) }
        end

        def average(values) = values.empty? ? nil : (values.sum.to_f / values.size).round(1)

        def by_night(weekdays) = weekdays.select(&:minutes_asleep).partition { it.minutes_asleep < SHORT_NIGHT }

        def by_week(days) = [days.last(WEEK), days[0...-WEEK]].map { it.select(&:resting_heart_rate) }

        def by_workout(weekdays, workouts)
          started = workouts.map { Blog::TimeZone.local(it.started_at) }
          mornings = started.select { it.hour < NOON }.to_set(&:to_date)
          worked_out = started.to_set(&:to_date)

          [weekdays.select { mornings.include?(it.day) }, weekdays.reject { worked_out.include?(it.day) }]
        end

        def compare(groups, measures)
          return if groups.any? { it.size < MINIMUM_DAYS }

          subject, rest = groups.map do |days|
            PatternGroup.new(days: days.size, averages: measures.to_h { [it, average(days.filter_map(&it))] })
          end
          Pattern.new(subject:, rest:)
        end
      end
    end
  end
end
