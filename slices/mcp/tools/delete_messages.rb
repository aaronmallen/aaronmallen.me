# frozen_string_literal: true

module MCP
  module Tools
    class DeleteMessages < Base
      description "Delete up to #{Blog::Contract::MAX_IDS} contact form messages at once. One that is missing " \
                  "deletes none. No undo. Each deleted message's subject comes marked untrusted. " \
                  "#{Untrusted::WARNING}"
      endpoint scope: Blog::Types::OAuthScope["delete"]
    end
  end
end
