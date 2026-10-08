# frozen_string_literal: true

module API
  module Serializers
    class DecisionTimelineComment < Serializer
      KINDS = [Blog::Types::DecisionTimelineKind["comment"]].freeze

      SCHEMA = Helpers::Schema.object(
        {
          kind: { type: "string", enum: KINDS },
          id: { type: "integer", description: "the comment's ID" },
          occurred_at: Helpers::Schema::STAMP,
          body: { type: "string", description: "the comment, in Markdown" },
        },
      ).freeze

      schema_attributes
      stamps :occurred_at

      def id(entry) = entry.source_id
    end
  end
end
