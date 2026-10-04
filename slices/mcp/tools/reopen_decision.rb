# frozen_string_literal: true

module MCP
  module Tools
    class ReopenDecision < Base
      description "Reopen a resolved or dropped decision with a Markdown reason. It clears the choice"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
