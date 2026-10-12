# frozen_string_literal: true

module MCP
  module Tools
    class SnoozeMailThreads < Base
      description "Snooze up to #{Blog::Contract::MAX_IDS} mail threads until a future time, out of the inbox until " \
                  "then. One that is missing snoozes none. #{Untrusted::MAIL_THREADS}"
      endpoint scope: Blog::Types::OAuthScope["mail"]
    end
  end
end
