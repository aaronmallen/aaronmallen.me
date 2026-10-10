# frozen_string_literal: true

module MCP
  module Tools
    class TagTasks < Base
      description "Add one private tag to up to #{Blog::Contract::MAX_IDS} tasks at once. One that is missing tags " \
                  "none. #{Untrusted::TASKS}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
