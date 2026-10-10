# frozen_string_literal: true

module MCP
  module Tools
    class IgnoreWebmentions < Base
      description "Hide up to #{Blog::Contract::MAX_IDS} webmentions as ignored, leaving their authors alone. One " \
                  "that is missing hides none. #{Untrusted::WEBMENTIONS}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
