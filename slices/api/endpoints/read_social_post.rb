# frozen_string_literal: true

module API
  module Endpoints
    class ReadSocialPost < Endpoint
      KIND = Blog::Types::RecordKind["social_post"]
      SCHEMA = { additionalProperties: false, properties: { id: SocialPosts::ID }, required: ["id"] }.freeze
      SUGGESTIONS = "the suggested edits still waiting on the author, in the order they apply"

      REPLY = Schema.widen(
        Serializers::SocialPost::SCHEMA,
        suggestion_edits: Schema.list(Serializers::SuggestionEdit.reference).merge(description: SUGGESTIONS),
        record_links: Serializers::Link::GROUPS,
      ).freeze

      include Deps[
        record_links: "links.queries.record_links",
        social_post_by_id: "social.queries.social_post_by_id",
        suggestion_for_social_post: "suggestions.queries.for_social_post",
      ]

      def handle(id:)
        social_post = social_post_by_id.call(id)
        return not_found(SocialPosts.missing(id)) if social_post.nil?

        Success(answered(social_post))
      end

      private

      def answered(social_post)
        serialized(Serializers::SocialPost, social_post).merge(
          suggestion_edits: serialized(Serializers::SuggestionEdit, open_edits(social_post)),
          record_links: linked(KIND, social_post.id),
        )
      end

      def open_edits(social_post)
        suggestion_for_social_post.call(social_post.id)&.open_edits || Blog::Constants::EMPTY_ARRAY
      end
    end
  end
end
