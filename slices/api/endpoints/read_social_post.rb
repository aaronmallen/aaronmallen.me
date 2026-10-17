# frozen_string_literal: true

module API
  module Endpoints
    class ReadSocialPost < SocialPostEndpoint
      KIND = Blog::Types::RecordKind["social_post"]
      SCHEMA = Helpers::Schema.by_id

      REPLY = Helpers::Schema.widen(
        SocialPostEndpoint::REPLY,
        **Helpers::Schema.suggestion,
        record_links: Serializers::Link::GROUPS,
      ).freeze

      include Deps[
        record_link_queries: "links.repos.record_link_queries",
        social_post_queries: "social.repos.social_post_queries",
        suggestion_queries: "suggestions.repos.suggestion_queries",
      ]

      def handle(id:)
        social_post = social_post_queries.by_id(id)
        return missing("social post", id) if social_post.nil?

        Success(read(social_post))
      end

      private

      def read(social_post)
        answered(social_post).merge(
          **suggested(suggestion_queries.for_social_post(social_post.id)),
          record_links: links_for(social_post.id),
        )
      end
    end
  end
end
