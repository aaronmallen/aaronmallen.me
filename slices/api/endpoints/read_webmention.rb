# frozen_string_literal: true

module API
  module Endpoints
    class ReadWebmention < Endpoint
      SCHEMA = Schema.by_id

      REPLY = Schema.widen(
        Serializers::Webmention::SCHEMA,
        post_title: { type: "string", description: "the title of the post the webmention names" },
        post_slug: { type: "string", description: "the slug of the post the webmention names" },
      ).freeze

      include Deps[post_by_id: "posts.queries.by_id", webmention_by_id: "social.queries.webmention_by_id"]

      def handle(id:)
        mention = webmention_by_id.call(id)
        post = mention && post_by_id.call(mention.post_id)
        return not_found(Webmentions.missing(id)) if post.nil?

        Success(answered(mention, post))
      end

      private

      def answered(mention, post)
        serialized(Serializers::Webmention, mention).merge(post_title: post.title, post_slug: post.slug)
      end
    end
  end
end
