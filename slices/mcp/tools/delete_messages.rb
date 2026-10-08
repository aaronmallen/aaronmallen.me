# frozen_string_literal: true

module MCP
  module Tools
    class DeleteMessages < Base
      description "Delete up to 100 contact form messages at once. One that is missing deletes none. No undo"
      endpoint scope: Blog::Types::OAuthScope["delete"]
    end
  end
end
