# frozen_string_literal: true

module MCP
  module Tools
    class CancelTasks < Base
      description "Cancel up to #{Blog::Contract::MAX_IDS} open tasks at once. One that is missing or already closed " \
                  "cancels none. #{Untrusted::TASKS}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
