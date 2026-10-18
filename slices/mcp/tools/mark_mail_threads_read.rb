# frozen_string_literal: true

module MCP
  module Tools
    class MarkMailThreadsRead < Base
      description "Mark up to #{Blog::Contract::MAX_IDS} mail threads read at once. One that is missing " \
                  "marks none. #{Untrusted::MAIL_THREADS}"
      endpoint
    end
  end
end
