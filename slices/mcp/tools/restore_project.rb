# frozen_string_literal: true

module MCP
  module Tools
    class RestoreProject < Base
      description "Restore one archived project to /projects as active"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
