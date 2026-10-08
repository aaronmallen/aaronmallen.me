# frozen_string_literal: true

module MCP
  module Tools
    class ResolveDecision < Base
      description "Resolve an open decision with one of its own options and a Markdown reason for the choice"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
