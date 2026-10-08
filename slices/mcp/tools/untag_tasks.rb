# frozen_string_literal: true

module MCP
  module Tools
    class UntagTasks < Base
      description "Take one private tag off up to 100 tasks at once. One that is missing changes none. " \
                  "#{Untrusted::TASKS}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
