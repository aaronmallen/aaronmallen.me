# frozen_string_literal: true

module MCP
  module Tools
    class ReopenDecision < Base
      description "Reopen a resolved or dropped decision with a Markdown reason. It clears the choice"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
