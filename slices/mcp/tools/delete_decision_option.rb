# frozen_string_literal: true

module MCP
  module Tools
    class DeleteDecisionOption < Base
      description "Delete one option of a decision. The option a decision was resolved with stays until it reopens. " \
                  "This cannot be undone"
      endpoint scope: OAuth::Scope::DELETE
    end
  end
end
