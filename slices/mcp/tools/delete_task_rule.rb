# frozen_string_literal: true

module MCP
  module Tools
    class DeleteTaskRule < Base
      description "Delete one task rule for good. Every task keeps the tags and project it has, and later " \
                  "imports stop taking the rule's tags and projects"
      endpoint
    end
  end
end
