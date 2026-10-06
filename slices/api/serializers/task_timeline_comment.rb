# frozen_string_literal: true

module API
  module Serializers
    class TaskTimelineComment < Serializer
      KINDS = [Blog::Types::TaskTimelineKind["comment"]].freeze

      SCHEMA = Schema.object(
        {
          kind: { type: "string", enum: KINDS },
          id: { type: "integer", description: "the comment's ID" },
          occurred_at: Schema::STAMP,
          body: { type: "string", description: "the comment, in Markdown" },
          author: Schema.nullable(Schema::STRING),
          source: TaskComment::SCHEMA.dig(:properties, :source),
          url: Schema.nullable(Schema::STRING),
        },
      ).freeze

      schema_attributes
      stamps :occurred_at

      def author(entry) = entry.synced? ? entry.author : Blog::Owner.full_name

      def id(entry) = entry.source_id

      def source(entry) = entry.provider || TaskComment::LOCAL
    end
  end
end
