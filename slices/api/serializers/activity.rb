# frozen_string_literal: true

module API
  module Serializers
    class Activity < Serializer
      POST = Blog::Types::ActivityKind["post"]
      CREDITS = "who did a task's work, the owner when it lists none, or null for any other kind"
      VIEWS = "a post's views over the last #{Analytics::Repos::AnalyticsRollupQueries::VIEW_DAYS} days, or null " \
              "for any other kind".freeze

      SCHEMA = Helpers::Schema.object(
        {
          kind: { type: "string", enum: Blog::Types::ActivityKind.values },
          source_id: Helpers::Schema::INTEGER,
          date: Helpers::Schema::DAY,
          time: { type: "string", description: "the time of day, as HH:MM" },
          name: Helpers::Schema::STRING,
          link: Helpers::Schema.nullable(Helpers::Schema::STRING),
          repo: Helpers::Schema.nullable(Helpers::Schema::STRING),
          sha: Helpers::Schema.nullable(Helpers::Schema::STRING),
          additions: Helpers::Schema.nullable(Helpers::Schema::INTEGER),
          deletions: Helpers::Schema.nullable(Helpers::Schema::INTEGER),
          status: Helpers::Schema.nullable(Helpers::Schema::STRING),
          targets: Helpers::Schema.nullable(Helpers::Schema::TAGS),
          excerpt: Helpers::Schema.nullable(Helpers::Schema::STRING),
          task_id: Helpers::Schema.nullable(Helpers::Schema::INTEGER),
          decision_id: Helpers::Schema.nullable(Helpers::Schema::INTEGER),
          worked_seconds: Helpers::Schema.nullable(Helpers::Schema::INTEGER),
          views: Helpers::Schema.nullable(Helpers::Schema::INTEGER).merge(description: VIEWS),
          tags: Helpers::Schema::TAGS,
          contributors: Helpers::Schema.nullable(Helpers::Schema.list(Task::CONTRIBUTOR)).merge(description: CREDITS),
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
