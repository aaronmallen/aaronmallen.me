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
        def call(server_context:) = answer(tokens: dep(:api_token_queries, server_context).live.map { entry(it) })

        private

        def entry(token)
          {
            id: token.id,
            name: token.name,
            created_at: token.created_at.utc.iso8601,
            last_used_at: token.last_used_at&.utc&.iso8601,
          }
        end
      end
    end
  end
end
