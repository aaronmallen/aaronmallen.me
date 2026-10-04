# frozen_string_literal: true

module MCP
  module Tools
    class ReadSocialPost < Base
      KIND = "social_post"
      SCHEMA = { additionalProperties: false, properties: { id: API::Schema::ID }, required: ["id"] }.freeze

      description "Read one social post that has not been sent yet: its status, its parts in order and the " \
                  "records linked to it, grouped by kind"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(id:, server_context:)
          social_post = editable_social_post(server_context).call(id)
          return refuse("no unsent social post has the ID #{id}") if social_post.nil?

          answer(
            id: social_post.id,
            status: social_post.status,
            parts: social_post.parts.map(&:body),
            record_links: record_links(KIND, social_post.id, server_context),
          )
        end
      end
    end
  end
end
