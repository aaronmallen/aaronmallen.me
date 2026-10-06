# frozen_string_literal: true

module API
  module Serializers
    class TaskTimelineTag < Serializer
      KINDS = %w[tagged untagged].map { Blog::Types::TaskTimelineKind[it] }.freeze

      SCHEMA = Schema.object(
        { kind: { type: "string", enum: KINDS }, occurred_at: Schema::STAMP, tag: Schema::STRING },
      ).freeze

      schema_attributes
      stamps :occurred_at

      def tag(entry) = entry.tag_name
    end
  end
end
