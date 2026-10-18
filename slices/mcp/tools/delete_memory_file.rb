# frozen_string_literal: true

module MCP
  module Tools
    class DeleteMemoryFile < Base
      description "Delete a memory file with its facts and history. This cannot be undone"
      endpoint scope: [Blog::Types::OAuthScope["agents"], Blog::Types::OAuthScope["delete"]]
    end
  end
end
