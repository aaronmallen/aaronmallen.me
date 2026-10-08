# frozen_string_literal: true

module API
  module Serializers
    class PostDetail < Serializer
      CARD = "for the social card; null when the post falls back to its own"
      SUMMARY = "the summary the author wrote; empty when the post falls back to its first paragraph"
      SYNDICATION = "the announcement the post sends when it goes out; empty sends its title and link"

      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          title: Helpers::Schema::STRING,
          slug: Helpers::Schema::STRING,
          status: { type: "string", enum: Blog::Types::PostStatus.values },
          summary: { type: "string", description: SUMMARY },
          tags: Helpers::Schema::TAGS,
          body: { type: "string", description: "the post, in Markdown" },
          published_at: Helpers::Schema.nullable(Helpers::Schema::STAMP),
          created_at: Helpers::Schema::STAMP,
          updated_at: Helpers::Schema::STAMP,
          og_title: Helpers::Schema.nullable({ type: "string", description: "the title #{CARD}" }),
          og_image_url: Helpers::Schema.nullable({ type: "string", description: "the image #{CARD}" }),
          canonical_url: Helpers::Schema.nullable(
            { type: "string", description: "the post's first home, when it has one" },
          ),
          syndication_enabled: Helpers::Schema::BOOLEAN,
          syndication_body: { type: "string", description: SYNDICATION },
          syndication_targets: Helpers::Schema.list({ type: "string", enum: Blog::Types::NetworkName.values }),
          webmentions_enabled: Helpers::Schema::BOOLEAN,
          word_count: Helpers::Schema::INTEGER,
          read_time: { type: "integer", description: "minutes to read the body" },
        },
      ).freeze

      schema_attributes
      stamps :created_at, :published_at, :updated_at
      tag_names

      def summary(post) = post.written_summary.to_s

      def syndication_targets(post) = post.syndication_targets.to_a

      def word_count(post) = ::Posts::Markdown.word_count(post.body)
    end
  end
end
