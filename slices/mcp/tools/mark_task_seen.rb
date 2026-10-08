# frozen_string_literal: true

module MCP
  module Tools
    class MarkTaskSeen < Base
      description "Mark one synced issue seen to clear it from the inbox; it stays in its list. " \
                  "A task with no synced issue is refused. " \
                  "#{Untrusted::TASK}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
