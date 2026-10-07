# frozen_string_literal: true

module MCP
  module Tools
    class UpdateSocialPost < Base
      DRAFT = Blog::Types::SocialIntent["draft"]

      SCHEMA = {
        additionalProperties: false,
        properties: {
          id: API::Schema::ID,
          parts: {
            type: "array",
            items: { type: "string" },
            description: "the text of each part in order; this list replaces every part the post has",
          },
          targets: {
            type: "array",
            items: { type: "string", enum: Blog::Types::NetworkName.values },
            description: "the networks it goes out to",
          },
        },
        required: ["id"],
      }.freeze

      description "Change the parts or the networks of one social post that has not gone out. A field you " \
                  "leave out keeps what it has. The edit leaves the post a draft, the way saving a draft in " \
                  "the admin does, so a queued post waits until send_social_post queues it again. The answer " \
                  "gives each part's length and limit on each network"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        include SocialPostAnswer

        def call(id:, server_context:, **fields)
          stored = dep(:social_post_queries, server_context).editable(id)
          params = { parts: stored&.parts&.map(&:body), targets: stored&.targets.to_a }.merge(fields)

          result = dep(:compose_social_post, server_context).call(params, intent: DRAFT, id:)

          composed(result, id, params, server_context)
        end
      end
    end
  end
end
