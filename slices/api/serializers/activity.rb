# frozen_string_literal: true

module API
  module Serializers
    class Activity < Serializer
      POST = Blog::Types::ActivityKind["post"]
      CREDITS = "who did a task's work, the owner when it lists none, or null for any other kind"
      VIEWS = "a post's views over the last 90 days, or null for any other kind"

      SCHEMA = Schema.object(
        {
          kind: { type: "string", enum: Blog::Types::ActivityKind.values },
          source_id: Schema::INTEGER,
          date: Schema::DAY,
          time: { type: "string", description: "the time of day, as HH:MM" },
          name: Schema::STRING,
          link: Schema.nullable(Schema::STRING),
          repo: Schema.nullable(Schema::STRING),
          sha: Schema.nullable(Schema::STRING),
          additions: Schema.nullable(Schema::INTEGER),
          deletions: Schema.nullable(Schema::INTEGER),
          status: Schema.nullable(Schema::STRING),
          targets: Schema.nullable(Schema::TAGS),
          excerpt: Schema.nullable(Schema::STRING),
          task_id: Schema.nullable(Schema::INTEGER),
          decision_id: Schema.nullable(Schema::INTEGER),
          worked_seconds: Schema.nullable(Schema::INTEGER),
          views: Schema.nullable(Schema::INTEGER).merge(description: VIEWS),
          tags: Schema::TAGS,
          contributors: Schema.nullable(Schema.list(Task::CONTRIBUTOR)).merge(description: CREDITS),
        },
      ).freeze

      schema_attributes

      def contributors(row) = row.contributors && Task.credits(row.contributors)

      def date(row) = day(row.occurred_on)

      def kind(row) = row.type

      def tags(row) = Array(row.tags)

      def targets(row) = row.targets&.to_a

      def time(row) = clock(row.occurred_at)

      def views(row) = (params.fetch(:views).fetch(row.link, 0) if row.type == POST)
    end
  end
end
