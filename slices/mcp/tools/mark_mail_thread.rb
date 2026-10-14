# frozen_string_literal: true

module MCP
  module Tools
    class MarkMailThread < Base
      description "Mark one mail thread from any account as unread, read or spam"
      endpoint scope: Blog::Types::OAuthScope["mail"]
    end
  end
end
