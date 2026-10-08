# frozen_string_literal: true

module API
  module Serializers
    class TaskTimelineMove < Serializer
      KINDS = [Blog::Types::TaskTimelineKind["moved"]].freeze

      LIST = Helpers::Schema.nullable({ type: "string", enum: Blog::Types::TaskList.values }).freeze

      SCHEMA = Helpers::Schema.object(
        {
          kind: { type: "string", enum: KINDS },
          occurred_at: Helpers::Schema::STAMP,
          from_list: LIST,
          from_sprint_on: Helpers::Schema.nullable(Helpers::Schema::DAY),
          to_list: LIST,
          to_sprint_on: Helpers::Schema.nullable(Helpers::Schema::DAY),
        },
      ).freeze

      schema_attributes
      stamps :occurred_at

      def from_sprint_on(entry) = day(entry.from_sprint_on)

      def to_sprint_on(entry) = day(entry.to_sprint_on)
    end
  end
end
