# frozen_string_literal: true

module MCP
  module Tools
    class DeleteWorkEntry < Base
      description "Remove one role from the work list on /projects for good"
      endpoint scope: Blog::Types::OAuthScope["delete"]
    end
  end
end
