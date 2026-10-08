# frozen_string_literal: true

module MCP
  module Tools
    class DropDecision < Base
      description "Drop an open decision without a choice, with a Markdown reason"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
