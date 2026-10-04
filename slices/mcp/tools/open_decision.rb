# frozen_string_literal: true

module MCP
  module Tools
    class OpenDecision < Base
      description "Open a decision with a title and a Markdown problem statement, as the admin does. It starts open, " \
                  "ready for options"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
