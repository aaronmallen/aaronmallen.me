# frozen_string_literal: true

module MCP
  module Tools
    class MoveTask < Base
      description "Move one task to next, someday, external or today's sprint. " \
                  "#{Untrusted::TASK}"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
