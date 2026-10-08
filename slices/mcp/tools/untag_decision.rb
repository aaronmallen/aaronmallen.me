# frozen_string_literal: true

module MCP
  module Tools
    class UntagDecision < Base
      description "Take one private tag off a decision"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
