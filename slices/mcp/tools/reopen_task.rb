# frozen_string_literal: true

module MCP
  module Tools
    class ReopenTask < Base
      description "Reopen one task, done, canceled or started: it goes back to open where it sits. " \
                  "#{Untrusted::TASK}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
