# frozen_string_literal: true

module API
  module Serializers
    class TimeGroup < Serializer
      TASK = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          title: Helpers::Schema::STRING,
          seconds: Helpers::Schema::INTEGER,
          shared: { type: "boolean", description: "whether this task's time also counts in another group" },
        },
      ).freeze

      SCHEMA = Helpers::Schema.object(
        {
          key: {
            type: %w[integer string null],
            description: "the project's ID, the tag or the day as YYYY-MM-DD; null for tasks with no project or tag",
          },
          name: Helpers::Schema.nullable(Helpers::Schema::STRING),
          seconds: Helpers::Schema::INTEGER,
          shared: { type: "boolean", description: "whether some of this time also counts in another group" },
          tasks: Helpers::Schema.list(TASK),
        },
      ).freeze

      schema_attributes

      def key(group) = group.key.is_a?(Date) ? day(group.key) : group.key

      def tasks(group) = group.tasks.map(&:to_h)
    end
  end
end
