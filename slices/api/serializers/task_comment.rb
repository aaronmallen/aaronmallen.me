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

      attributes :id, :body, :author, :source, :url, :created_at, :updated_at

      def author(comment) = comment.remote_id ? comment.author : Blog::Owner.full_name

      def created_at(comment) = stamp(comment.created_at)

      def source(comment) = comment.provider || LOCAL

      def updated_at(comment) = stamp(comment.updated_at)
    end
  end
end
