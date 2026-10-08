# frozen_string_literal: true

module MCP
  module Tools
    class TagDecision < Base
      description "Add private tags to a decision. The tags it already carries stay"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
