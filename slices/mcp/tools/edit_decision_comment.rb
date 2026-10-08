# frozen_string_literal: true

module MCP
  module Tools
    class EditDecisionComment < Base
      description "Replace the body of one comment on a decision"
      endpoint scope: Blog::Types::OAuthScope["write"]
    end
  end
end
