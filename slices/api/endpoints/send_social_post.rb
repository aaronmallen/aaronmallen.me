# frozen_string_literal: true

module API
  module Endpoints
    class SendSocialPost < SocialPostEndpoint
      NOW = Blog::Types::SocialMode["now"]
      SCHEDULE = Blog::Types::SocialMode["schedule"]
      SEND = Blog::Types::SocialIntent["send"]

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: Schema::ID,
          schedule_at: {
            type: "string",
            description: "when to send it, as YYYY-MM-DDTHH:MM in #{Blog::TimeZone::NAME}; leave it out for now",
          },
        },
        required: ["id"],
      }.freeze

      include Deps[compose_social_post: "social.operations.compose_social_post"]

      def handle(id:, schedule_at: nil)
        stored = social_post_queries.editable(id)
        params = {
          parts: stored&.parts&.map(&:body),
          targets: stored&.targets.to_a,
          mode: schedule_at ? SCHEDULE : NOW,
          schedule_at:,
        }

        composed(compose_social_post.call(params, intent: SEND, id:), id, params)
      end
    end
  end
end
