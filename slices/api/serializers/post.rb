# frozen_string_literal: true

module API
  module Serializers
    class Post < Serializer
      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          title: Schema::STRING,
          slug: Schema::STRING,
          status: { type: "string", enum: Blog::Types::PostStatus.values },
          published_at: Schema.nullable(Schema::STAMP),
          tags: Schema::TAGS,
          updated_at: Schema::STAMP,
        },
      ).freeze

      attributes :id, :title, :slug, :status, :published_at, :tags, :updated_at

      def published_at(post) = stamp(post.published_at)

      def tags(post) = post.tags.map(&:name)

      def updated_at(post) = stamp(post.updated_at)
    end
  end
end
