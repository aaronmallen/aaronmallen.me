# frozen_string_literal: true

module MCP
  module Tools
    class SendSocialPost < Base
      NOW = Blog::Types::SocialMode["now"]
      SCHEDULE = Blog::Types::SocialMode["schedule"]
      SEND = Blog::Types::SocialIntent["send"]

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: API::Schema::ID,
          schedule_at: {
            type: "string",
            description: "when to send it, as YYYY-MM-DDTHH:MM in #{Blog::TimeZone::NAME}; leave it out for now",
          },
        },
        required: ["id"],
      }.freeze

      description "Queue one social post that has not gone out, to send now or at a set time, the way the admin " \
                  "does. It goes out to every network it targets, and a sent post cannot be called back. " \
                  "The post is refused if a part runs over a network's limit or a network has no credentials"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        include SocialPostAnswer

        def call(id:, server_context:, schedule_at: nil)
          stored = dep(:editable_social_post, server_context).call(id)
          params = {
            parts: stored&.parts&.map(&:body),
            targets: stored&.targets.to_a,
            mode: schedule_at ? SCHEDULE : NOW,
            schedule_at:,
          }

          composed(dep(:compose_social_post, server_context).call(params, intent: SEND, id:), id)
        end
      end
    end
  end
end
