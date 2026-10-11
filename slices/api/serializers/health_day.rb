# frozen_string_literal: true

module API
  module Serializers
    class HealthDay < Serializer
      COUNT = Helpers::Schema::INTEGER
      MEASURE = Helpers::Schema.nullable(Helpers::Schema::INTEGER)
      STAMP = Helpers::Schema.nullable(Helpers::Schema::STAMP)

      SCHEMA = Helpers::Schema.object(
        {
          day: Helpers::Schema::DAY,
          minutes_asleep: MEASURE.merge(description: "the night that ended this morning; null with no data"),
          bed_at: STAMP,
          woke_at: STAMP,
          resting_heart_rate: MEASURE,
          hrv: Helpers::Schema.nullable({ type: "number" }),
          steps: MEASURE,
          active_zone_minutes: MEASURE,
          focus_minutes: COUNT.merge(description: "minutes worked on tasks, overlapping time counted once"),
          commits: COUNT,
          late_commits: COUNT.merge(description: "commits made from 22:00 on"),
          tasks_done: COUNT,
          pull_requests_opened: COUNT,
          pull_requests_merged: COUNT,
          journal_entries: COUNT,
          first_active_at: STAMP,
          last_active_at: STAMP,
        },
      ).freeze

      schema_attributes

      stamps :bed_at, :woke_at, :first_active_at, :last_active_at

      def day(record) = super(record.day)
    end
  end
end
