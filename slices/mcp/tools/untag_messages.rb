# frozen_string_literal: true

module MCP
  module Tools
    class UntagMessages < Base
      description "Take one private tag off up to #{Blog::Contract::MAX_IDS} contact form messages at once. One that " \
                  "is missing changes none. #{Untrusted::MESSAGES}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
