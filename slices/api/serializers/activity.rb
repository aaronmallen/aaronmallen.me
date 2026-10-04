# frozen_string_literal: true

module API
  module Serializers
    class Activity < Serializer
      TIME_FORMAT = "%H:%M"

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
          tags: Schema::TAGS,
        },
      ).freeze

      attributes :kind, :source_id, :date, :time, :name, :link, :repo, :sha, :additions, :deletions, :status
      attributes :targets, :excerpt, :task_id, :decision_id, :worked_seconds, :tags

      def date(row) = day(row.occurred_on)

      def kind(row) = row.type

      def tags(row) = Array(row.tags)

      def targets(row) = row.targets&.to_a

      def time(row) = row.occurred_at.strftime(TIME_FORMAT)
    end
  end
end
