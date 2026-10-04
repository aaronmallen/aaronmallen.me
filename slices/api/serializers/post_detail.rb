# frozen_string_literal: true

module API
  module Serializers
    class PostDetail < Serializer
      CARD = "for the social card; null when the post falls back to its own"
      SUMMARY = "the summary the author wrote; empty when the post falls back to its first paragraph"
      SYNDICATION = "the announcement the post sends when it goes out; empty sends its title and link"

      SCHEMA = Schema.object(
        {
          id: Schema::INTEGER,
          title: Schema::STRING,
          slug: Schema::STRING,
          status: { type: "string", enum: Blog::Types::PostStatus.values },
          summary: { type: "string", description: SUMMARY },
          tags: Schema::TAGS,
          body: { type: "string", description: "the post, in Markdown" },
          published_at: Schema.nullable(Schema::STAMP),
          created_at: Schema::STAMP,
          updated_at: Schema::STAMP,
          og_title: Schema.nullable({ type: "string", description: "the title #{CARD}" }),
          og_image_url: Schema.nullable({ type: "string", description: "the image #{CARD}" }),
          canonical_url: Schema.nullable({ type: "string", description: "the post's first home, when it has one" }),
          syndication_enabled: Schema::BOOLEAN,
          syndication_body: { type: "string", description: SYNDICATION },
          syndication_targets: Schema.list({ type: "string", enum: Blog::Types::NetworkName.values }),
          webmentions_enabled: Schema::BOOLEAN,
          word_count: Schema::INTEGER,
          read_time: { type: "integer", description: "minutes to read the body" },
        },
      ).freeze

      attributes :id, :title, :slug, :status, :summary, :tags, :body, :published_at, :created_at, :updated_at
      attributes :og_title, :og_image_url, :canonical_url
      attributes :syndication_enabled, :syndication_body, :syndication_targets, :webmentions_enabled
      attributes :word_count, :read_time

      def created_at(post) = stamp(post.created_at)

      def published_at(post) = stamp(post.published_at)

      def summary(post) = post.written_summary.to_s

      def syndication_targets(post) = post.syndication_targets.to_a

      def tags(post) = post.tags.map(&:name)

      def updated_at(post) = stamp(post.updated_at)

      def word_count(post) = ::Posts::Markdown.word_count(post.body)
    end
  end
end
