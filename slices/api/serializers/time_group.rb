# frozen_string_literal: true

module API
  module Serializers
    class TimeGroup < Serializer
      SCHEMA = Schema.object(
        {
          key: {
            type: %w[integer string null],
            description: "the project's ID, the tag or the day as YYYY-MM-DD; null for tasks with no project or tag",
          },
          name: Schema.nullable(Schema::STRING),
          seconds: Schema::INTEGER,
          shared: { type: "boolean", description: "whether some of this time also counts in another group" },
          tasks: Schema.list(
            Schema.object(
              {
                id: Schema::INTEGER,
                title: Schema::STRING,
                seconds: Schema::INTEGER,
                shared: { type: "boolean", description: "whether this task's time also counts in another group" },
              },
            ),
          ),
        },
      ).freeze

      attributes :key, :name, :seconds, :shared, :tasks

      def key(group) = group.key.is_a?(Date) ? day(group.key) : group.key

      def tasks(group) = group.tasks.map(&:to_h)
    end
  end
end
