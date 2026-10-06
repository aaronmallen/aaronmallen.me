# frozen_string_literal: true

module API
  module Serializers
    class TaskComment < Serializer
      LOCAL = "local"

      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          body: { type: "string", description: "the comment, in Markdown" },
          author: Schema.nullable(Schema::STRING),
          source: { type: "string", enum: [LOCAL, *Blog::Types::TaskSourceProvider.values] },
          url: Schema.nullable(Schema::STRING),
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :created_at, :updated_at

      def author(comment) = comment.remote_id ? comment.author : Blog::Owner.full_name

      def source(comment) = comment.provider || LOCAL
    end
  end
end
