# frozen_string_literal: true

module MCP
  module Tools
    class UnlinkTask < Base
      description "Remove the link between two tasks, whichever way it runs. " \
                  "#{Untrusted::TASK}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
