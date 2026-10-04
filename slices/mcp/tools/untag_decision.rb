# frozen_string_literal: true

module MCP
  module Tools
    class UntagDecision < Base
      description "Take one private tag off a decision"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
