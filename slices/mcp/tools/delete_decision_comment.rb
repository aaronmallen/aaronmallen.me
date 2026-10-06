# frozen_string_literal: true

module MCP
  module Tools
    class DeleteDecisionComment < Base
      description "Delete one comment on a decision. This cannot be undone"
      endpoint scope: OAuth::Scope::DELETE
    end
  end
end
