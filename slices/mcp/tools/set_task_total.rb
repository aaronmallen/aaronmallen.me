# frozen_string_literal: true

module MCP
  module Tools
    class SetTaskTotal < Base
      description "Set the total time worked on one task, in hours and minutes, in place of what it has. " \
                  "Use it for time nobody tracked; later sessions add to it. " \
                  "#{Untrusted::TASK}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
