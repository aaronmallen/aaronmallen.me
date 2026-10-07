# frozen_string_literal: true

module API
  module Endpoints
    class ReadSocialPost < Endpoint
      KIND = Blog::Types::RecordKind["social_post"]
      LENGTH = Schema.object({ count: Schema::INTEGER, limit: Schema::INTEGER })
      LENGTHS = "for each part in order, its length on each network it targets, counted the way send counts"
      NETWORKS = Blog::Types::NetworkName.values.to_h { [it.to_sym, LENGTH] }
      SCHEMA = Schema.by_id
      SUGGESTION = "the suggestion that holds the open edits, to accept or reject them; null when none is open"
      SUGGESTIONS = "the suggested edits still waiting on the author, in the order they apply"

      REPLY = Schema.widen(
        Serializers::SocialPost::SCHEMA,
        suggestion_id: Schema.nullable(Schema::ID).merge(description: SUGGESTION),
        suggestion_edits: Schema.list(Serializers::SuggestionEdit.reference).merge(description: SUGGESTIONS),
        lengths: Schema.list(Schema.object({}, optional: NETWORKS)).merge(description: LENGTHS),
        record_links: Serializers::Link::GROUPS,
      ).freeze

      include Deps[
        measure_parts: "social.operations.measure_parts",
        record_links: "links.queries.record_links",
        social_post_queries: "social.repos.social_post_queries",
        suggestion_for_social_post: "suggestions.queries.for_social_post",
      ]

      def handle(id:)
        social_post = social_post_queries.by_id(id)
        return not_found(Wording.missing("social post", id)) if social_post.nil?

        Success(answered(social_post))
      end

      private

      def answered(social_post)
        serialized(Serializers::SocialPost, social_post).merge(
          **suggested(suggestion_for_social_post.call(social_post.id)),
          lengths: lengths(social_post),
          record_links: linked(KIND, social_post.id),
        )
      end

      def lengths(social_post)
        measured = measure_parts.call(social_post.parts.map(&:body), social_post.targets.to_a)

        measured.map { |part| part.transform_values(&:counted) }
      end
    end
  end
end
