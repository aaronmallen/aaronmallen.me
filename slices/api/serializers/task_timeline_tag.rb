# frozen_string_literal: true

module API
  module Serializers
    class TaskTimelineTag < Serializer
      KINDS = %w[tagged untagged].map { Blog::Types::TaskTimelineKind[it] }.freeze

      SCHEMA = Schema.object(
        { kind: { type: "string", enum: KINDS }, occurred_at: Schema::STAMP, tag: Schema::STRING },
      ).freeze

      attributes :kind, :occurred_at, :tag

      def occurred_at(entry) = stamp(entry.occurred_at)

      def tag(entry) = entry.tag_name
    end
  end
end
