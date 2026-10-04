# frozen_string_literal: true

module API
  module Serializers
    class TaskTimelineMove < Serializer
      KINDS = [Blog::Types::TaskTimelineKind["moved"]].freeze

      LIST = Schema.nullable({ type: "string", enum: Blog::Types::TaskList.values }).freeze

      SCHEMA = Schema.object(
        {
          kind: { type: "string", enum: KINDS },
          occurred_at: Schema::STAMP,
          from_list: LIST,
          from_sprint_on: Schema.nullable(Schema::DAY),
          to_list: LIST,
          to_sprint_on: Schema.nullable(Schema::DAY),
        },
      ).freeze

      attributes :kind, :occurred_at, :from_list, :from_sprint_on, :to_list, :to_sprint_on

      def from_sprint_on(entry) = day(entry.from_sprint_on)

      def occurred_at(entry) = stamp(entry.occurred_at)

      def to_sprint_on(entry) = day(entry.to_sprint_on)
    end
  end
end
