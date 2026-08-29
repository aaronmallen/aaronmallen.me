# frozen_string_literal: true

module MCP
  module Tools
    class CreateSocialPost < Base
      DRAFT = Blog::Types::SocialIntent["draft"]

      SCHEMA = {
        additionalProperties: false,
        properties: {
          parts: {
            type: "array",
            items: { type: "string" },
            description: "the text of each part in order; the first goes out alone and each next part replies to it",
          },
          targets: {
            type: "array",
            items: { type: "string", enum: Blog::Types::NetworkName.values },
            description: "the networks it goes out to",
          },
        },
        required: %w[parts targets],
      }.freeze

      description "Write a new social post and save it as a draft. Nothing goes out until send_social_post " \
                  "queues it"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        include SocialPostAnswer

        def call(parts:, targets:, server_context:)
          composed(compose_social_post(server_context).call({ parts:, targets: }, intent: DRAFT), nil)
        end
      end
    end
  end
end
