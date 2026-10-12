# frozen_string_literal: true

module MCP
  module Tools
    class TagMailThreads < Base
      description "Add one private tag to up to #{Blog::Contract::MAX_IDS} mail threads at once. One that " \
                  "is missing tags none. #{Untrusted::MAIL_THREADS}"
      endpoint scope: Blog::Types::OAuthScope["mail"]
    end
  end
end
