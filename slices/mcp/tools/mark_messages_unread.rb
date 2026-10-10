# frozen_string_literal: true

module MCP
  module Tools
    class MarkMessagesUnread < Base
      description "Mark up to #{Blog::Contract::MAX_IDS} contact form messages unread at once. One that is missing " \
                  "marks none. #{Untrusted::MESSAGES}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
