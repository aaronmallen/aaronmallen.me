# frozen_string_literal: true

module Admin
  module Operations
    class ReviewSocialEdits
      include Deps[
        find_over_limit_network: "operations.find_over_limit_network",
        suggestion_queries: "suggestions.repos.suggestion_queries",
      ]

      def call(social_post)
        {
          edits: edits(social_post),
          parts: social_post ? social_post.parts.length : 0,
          social_post_id: social_post&.id,
        }
      end

      private

      def edits(social_post)
        suggestion = suggestion_queries.for_social_post(social_post.id) if social_post
        return Blog::Constants::EMPTY_ARRAY unless suggestion

        suggestion.open_edits.sort_by { [it.part_number, it.position] }.map { review(social_post, it) }
      end

      def review(social_post, edit)
        stale = stale?(social_post, edit)

        {
          id: edit.id,
          original: edit.original,
          over: stale ? nil : find_over_limit_network.call(social_post, edit),
          part: edit.part_number,
          reason: edit.reason,
          replacement: edit.replacement,
          stale:,
        }
      end

      def stale?(social_post, edit)
        body = social_post.parts.map(&:body)[edit.part_number - 1]

        edit.stale? || body.nil? || !edit.applies_to?(body)
      end
    end
  end
end
