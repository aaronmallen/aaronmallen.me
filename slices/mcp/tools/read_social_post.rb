# frozen_string_literal: true

module MCP
  module Tools
    class ReadSocialPost < Base
      SCHEMA = { additionalProperties: false, properties: { id: { type: "integer" } }, required: ["id"] }.freeze

      description "Read one social post that has not been sent yet: its status and its parts in order"
      input_schema(SCHEMA)
      scope OAuth::Scope::READ

      class << self
        def call(id:, server_context:)
          social_post = editable_social_post(server_context).call(id)
          return refuse("no unsent social post has the ID #{id}") if social_post.nil?

          answer(id: social_post.id, status: social_post.status, parts: social_post.parts.map(&:body))
        end
      end
    end
  end
end
