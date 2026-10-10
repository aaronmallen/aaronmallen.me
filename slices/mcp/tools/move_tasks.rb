# frozen_string_literal: true

module MCP
  module Tools
    class MoveTasks < Base
      description "Move up to #{Blog::Contract::MAX_IDS} tasks to next, someday, external or today's sprint. One " \
                  "that is missing moves none. #{Untrusted::TASKS}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
