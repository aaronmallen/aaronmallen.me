# frozen_string_literal: true

module MCP
  module Tools
    class UntagMailThreads < Base
      description "Take one private tag off up to #{Blog::Contract::MAX_IDS} mail threads at once. One " \
                  "that is missing changes none. #{Untrusted::MAIL_THREADS}"
      endpoint
    end
  end
end
