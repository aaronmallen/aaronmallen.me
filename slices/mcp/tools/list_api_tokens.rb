# frozen_string_literal: true

module MCP
  module Tools
    class ListAPITokens < Base
      SCHEMA = { additionalProperties: false }.freeze

      description "List the live API tokens, newest first, each with its ID, name, when it was minted and when it " \
                  "was last used, null if never. The token itself never comes back. Minting and revoking stay in " \
                  "the admin"
      input_schema(SCHEMA)
      scope Blog::Types::OAuthScope["read"]

      class << self
        def call(server_context:)
          answer(tokens: API::Serializers::APIToken.new(dep(:api_token_queries, server_context).live).serializable_hash)
        end
      end
    end
  end
end
