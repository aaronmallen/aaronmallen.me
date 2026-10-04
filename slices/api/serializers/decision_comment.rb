# frozen_string_literal: true

module API
  module Serializers
    class DecisionComment < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          body: { type: "string", description: "the comment, in Markdown" },
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
        },
      ).freeze

      attributes :id, :body, :created_at, :updated_at

      def created_at(comment) = stamp(comment.created_at)

      def updated_at(comment) = stamp(comment.updated_at)
    end
  end
end
