# frozen_string_literal: true

module MCP
  module Tools
    class IgnoreWebmentions < Base
      description "Hide up to #{Blog::Contract::MAX_IDS} webmentions as ignored, leaving their authors alone. One " \
                  "that is missing hides none. #{Untrusted::WEBMENTIONS}"
      endpoint
    end
  end
end
