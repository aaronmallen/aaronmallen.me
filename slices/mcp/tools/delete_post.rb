# frozen_string_literal: true

module MCP
  module Tools
    class DeletePost < Base
      description "Delete one blog post, in any status, for good"
      endpoint scope: Blog::Types::OAuthScope["delete"]
    end
  end
end
