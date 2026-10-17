# frozen_string_literal: true

module Health
  module Repos
    class HealthQueries < Blog::DB::Repo
      BASELINE = %i[minutes_asleep hrv resting_heart_rate].freeze
      BASELINE_DAYS = 30

      def days(from:, to:) = health_days.where(day: from..to).to_a.to_h { [it.day, it] }

      def held_backfills = held_health_backfills.oldest_first.to_a

      def report(from:, to:)
        days = health_days.with_work(from, to).map { Structs::Day.new(**it) }
        found = workouts.between(from, to).to_a

        Structs::Report.new(
          from:, to:, days:, workouts: found, baseline: baseline(to), patterns: Structs::Patterns.from(days, found),
        )
      end

      private

      def baseline(to)
        found = health_days.averages_between(to - BASELINE_DAYS + 1, to, BASELINE)

        Structs::Baseline.new(**found.transform_values { it&.to_f&.round(1) })
      end
    end
  end
end
