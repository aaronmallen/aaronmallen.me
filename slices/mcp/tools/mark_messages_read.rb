# frozen_string_literal: true

module MCP
  module Tools
    class MarkMessagesRead < Base
      description "Mark up to 100 contact form messages read at once. One that is missing marks none. " \
                  "#{Untrusted::MESSAGES}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
