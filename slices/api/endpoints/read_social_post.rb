# frozen_string_literal: true

module API
  module Endpoints
    class ReadSocialPost < SocialPostEndpoint
      KIND = Blog::Types::RecordKind["social_post"]
      SCHEMA = Helpers::Schema.by_id
      SUGGESTION = "the suggestion that holds the open edits, to accept or reject them; null when none is open"
      SUGGESTIONS = "the suggested edits still waiting on the author, in the order they apply"

      REPLY = Helpers::Schema.widen(
        SocialPostEndpoint::REPLY,
        suggestion_id: Helpers::Schema.nullable(Helpers::Schema::ID).merge(description: SUGGESTION),
        suggestion_edits: Helpers::Schema.list(Serializers::SuggestionEdit.reference).merge(description: SUGGESTIONS),
        record_links: Serializers::Link::GROUPS,
      ).freeze

      include Deps[
        record_link_queries: "links.repos.record_link_queries",
        suggestion_queries: "suggestions.repos.suggestion_queries",
      ]

      def handle(id:)
        social_post = social_post_queries.by_id(id)
        return not_found(Helpers::Wording.missing("social post", id)) if social_post.nil?

        Success(read(social_post))
      end

      private

      def read(social_post)
        answered(social_post).merge(
          **suggested(suggestion_queries.for_social_post(social_post.id)),
          record_links: linked(KIND, social_post.id),
        )
      end
    end
  end
end
