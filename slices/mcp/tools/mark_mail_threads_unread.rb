# frozen_string_literal: true

module MCP
  module Tools
    class MarkMailThreadsUnread < Base
      description "Mark up to #{Blog::Contract::MAX_IDS} mail threads unread at once. One that is missing " \
                  "marks none. #{Untrusted::MAIL_THREADS}"
      endpoint scope: Blog::Types::OAuthScope["mail"]
    end
  end
end
