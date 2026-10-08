# frozen_string_literal: true

module API
  module Endpoints
    class UpdateSocialPost < SocialPostEndpoint
      DRAFT = Blog::Types::SocialIntent["draft"]

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Helpers::Schema::ID,
          parts: {
            type: "array",
            items: { type: "string" },
            description: "the text of each part in order; this list replaces every part the post has",
          },
          targets: TARGETS,
        },
        required: ["id"],
      }.freeze

      include Deps[compose_social_post: "social.operations.compose_social_post"]

      def handle(id:, **fields)
        stored = social_post_queries.editable(id)
        params = { parts: stored&.parts&.map(&:body), targets: stored&.targets.to_a }.merge(fields)

        composed(compose_social_post.call(params, intent: DRAFT, id:), id, params)
      end
    end
  end
end
