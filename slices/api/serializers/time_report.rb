# frozen_string_literal: true

module API
  module Serializers
    class TimeReport < Serializer
      SCHEMA = Schema.object(
        {
          from: Schema::DAY,
          to: Schema::DAY,
          by: { type: "string", enum: Blog::Types::TimeGrouping.values },
          seconds: { type: "integer", description: "the time worked in the range, each task counted once" },
          groups: Schema.list(TimeGroup.reference),
        },
      ).freeze

      schema_attributes

      def from(report) = day(report.from)

      def groups(report) = TimeGroup.new(report.groups).serializable_hash

      def to(report) = day(report.to)
    end
  end
end
