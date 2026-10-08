# frozen_string_literal: true

module MCP
  module Tools
    class DeleteSocialPost < Base
      description "Delete one social post that has not gone out. A post a network has already taken stays"
      endpoint scope: Blog::Types::OAuthScope["delete"]
    end
  end
end
