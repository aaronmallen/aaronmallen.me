# frozen_string_literal: true

module MCP
  module Tools
    class CompleteTasks < Base
      description "Mark up to #{Blog::Contract::MAX_IDS} open or started tasks done at once, stamped with the time " \
                  "now. One that is missing or already closed completes none. #{Untrusted::TASKS}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
