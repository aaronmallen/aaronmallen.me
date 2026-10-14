# frozen_string_literal: true

module MCP
  module Tools
    class ListAPITokens < Base
      description "List the live API tokens, newest first, each with its ID, name, when it was minted and when it " \
                  "was last used, null if never. Last use updates at most every " \
                  "#{Operations::Authenticate::TOUCH_EVERY / 60} minutes. The token itself never comes back. " \
                  "Minting and revoking stay in the admin"
      endpoint scope: Blog::Types::OAuthScope["read"]
    end
  end
end
