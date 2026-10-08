# frozen_string_literal: true

module MCP
  module Tools
    class DeleteTasks < Base
      description "Delete up to 100 tasks and every link to or from them. One that is missing deletes none. No undo"
      endpoint scope: Blog::Types::OAuthScope["delete"]
    end
  end
end
