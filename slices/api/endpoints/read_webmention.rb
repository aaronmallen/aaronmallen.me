# frozen_string_literal: true

module API
  module Endpoints
    class ReadWebmention < Endpoint
      SCHEMA = Helpers::Schema.by_id

      REPLY = Helpers::Schema.widen(
        Serializers::Webmention::SCHEMA,
        post_title: { type: "string", description: "the title of the post the webmention names" },
        post_slug: { type: "string", description: "the slug of the post the webmention names" },
      ).freeze

      include Deps[post_queries: "posts.repos.post_queries", webmention_queries: "social.repos.webmention_queries"]

      def handle(id:)
        mention = webmention_queries.by_id(id)
        post = mention && post_queries.by_id(mention.post_id)
        return not_found(Helpers::Wording.missing("webmention", id)) if post.nil?

        Success(answered(mention, post))
      end

      private

      def answered(mention, post)
        serialized(Serializers::Webmention, mention).merge(post_title: post.title, post_slug: post.slug)
      end
    end
  end
end
