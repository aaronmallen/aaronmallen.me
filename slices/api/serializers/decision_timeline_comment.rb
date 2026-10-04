# frozen_string_literal: true

module API
  module Serializers
    class DecisionTimelineComment < Serializer
      KINDS = [Blog::Types::DecisionTimelineKind["comment"]].freeze

      SCHEMA = Schema.object(
        {
          kind: { type: "string", enum: KINDS },
          id: { type: "integer", description: "the comment's ID" },
          occurred_at: Schema::STAMP,
          body: { type: "string", description: "the comment, in Markdown" },
        },
      ).freeze

      attributes :kind, :id, :occurred_at, :body

      def id(entry) = entry.source_id

      def occurred_at(entry) = stamp(entry.occurred_at)
    end
  end
end
