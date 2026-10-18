# frozen_string_literal: true

module MCP
  module Tools
    class DeleteArtifact < Base
      description "Delete an artifact with every version. This cannot be undone"
      endpoint scope: [Blog::Types::OAuthScope["agents"], Blog::Types::OAuthScope["delete"]]
    end
  end
end
