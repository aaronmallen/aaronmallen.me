# frozen_string_literal: true

module MCP
  module Tools
    class DeleteTaskTagRule < Base
      description "Delete one task tag rule for good. Every task keeps the tags it has, and later imports stop " \
                  "taking the rule's tags"
      endpoint scope: OAuth::Scope::DELETE
    end
  end
end
