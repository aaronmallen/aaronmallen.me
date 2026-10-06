# frozen_string_literal: true

module MCP
  module Tools
    class DeleteSocialPost < Base
      SCHEMA = { additionalProperties: false, properties: { id: API::Schema::ID }, required: ["id"] }.freeze

      description "Delete one social post that has not gone out. A post a network has already taken stays"
      input_schema(SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(id:, server_context:)
          case dep(:delete_social_post, server_context).call(id)
          in Success(_) then answer(id:, deleted: true)
          in Failure(:already_posted) then refuse("social post #{id} has gone out, so nothing was removed")
          in Failure(:not_found) then refuse(API::Wording.missing("social post", id))
          else refuse("could not delete the social post")
          end
        end
      end
    end
  end
end
