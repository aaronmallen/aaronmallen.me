# frozen_string_literal: true

module API
  module Endpoints
    class CreateSocialPost < SocialPostEndpoint
      DRAFT = Blog::Types::SocialIntent["draft"]

      SCHEMA = {
        additionalProperties: false,
        properties: {
          parts: {
            type: "array",
            items: { type: "string" },
            description: "the text of each part in order; the first goes out alone and each next part replies to it",
          },
          targets: TARGETS,
        },
        required: %w[parts targets],
      }.freeze

      include Deps[compose_social_post: "social.operations.compose_social_post"]

      def handle(parts:, targets:)
        params = { parts:, targets: }

        composed(compose_social_post.call(params, intent: DRAFT), nil, params)
      end
    end
  end
end
