# frozen_string_literal: true

module API
  module Serializers
    class Workout < Serializer
      MEASURE = Helpers::Schema.nullable(Helpers::Schema::INTEGER)

      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          kind: { type: "string", description: "the kind Google names, such as RUNNING" },
          started_at: Helpers::Schema::STAMP,
          minutes: Helpers::Schema::INTEGER,
          distance_meters: Helpers::Schema.nullable({ type: "number" }),
          average_heart_rate: MEASURE,
          zone_minutes: MEASURE,
          kcal: MEASURE,
          device: Helpers::Schema.nullable(Helpers::Schema::STRING),
        },
      ).freeze

      schema_attributes

      stamps :started_at
    end
  end
end
