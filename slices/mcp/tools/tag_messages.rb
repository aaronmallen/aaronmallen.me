# frozen_string_literal: true

module MCP
  module Tools
    class TagMessages < Base
      description "Add one private tag to up to #{Blog::Contract::MAX_IDS} contact form messages at once. One that " \
                  "is missing tags none. #{Untrusted::MESSAGES}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
