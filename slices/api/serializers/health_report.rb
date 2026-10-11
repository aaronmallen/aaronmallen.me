# frozen_string_literal: true

module API
  module Serializers
    class HealthReport < Serializer
      AVERAGE = Helpers::Schema.nullable({ type: "number" })
      GROUP = Helpers::Schema.object(
        {
          days: { type: "integer", description: "how many days the group holds" },
          averages: { type: "object", additionalProperties: AVERAGE,
                      description: "each measure's mean over the group" },
        },
      ).freeze
      PATTERN = {
        type: %w[object null],
        additionalProperties: false,
        properties: { subject: GROUP, rest: GROUP },
        required: %w[subject rest],
      }.freeze

      def self.pattern(description) = PATTERN.merge(description: "#{description}; null under 3 days a group")

      SCHEMA = Helpers::Schema.object(
        {
          from: Helpers::Schema::DAY,
          to: Helpers::Schema::DAY,
          days: Helpers::Schema.list(HealthDay.reference),
          workouts: Helpers::Schema.list(Workout.reference),
          baseline: Helpers::Schema.object(
            { minutes_asleep: AVERAGE, hrv: AVERAGE, resting_heart_rate: AVERAGE },
          ).merge(description: "the means over the 30 days up to to"),
          patterns: Helpers::Schema.object(
            {
              short_nights: pattern("focus on weekdays after under 6 hours asleep, against the other weekdays"),
              morning_workouts: pattern("focus on weekdays with a workout before noon, against weekdays without one"),
              late_commits: pattern("sleep and HRV the night after a commit from 22:00 on, against the other nights"),
              resting_heart_rate: pattern("resting heart rate over the last 7 days, against the days before"),
            },
          ),
        },
      ).freeze

      schema_attributes

      def baseline(report) = report.baseline.to_h

      def days(report) = HealthDay.new(report.days).serializable_hash

      def from(report) = day(report.from)

      def patterns(report)
        report.patterns.to_h.transform_values { it && { subject: it.subject.to_h, rest: it.rest.to_h } }
      end

      def to(report) = day(report.to)

      def workouts(report) = Workout.new(report.workouts).serializable_hash
    end
  end
end
