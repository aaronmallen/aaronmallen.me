# frozen_string_literal: true

module MCP
  module Tools
    class DropDecision < Base
      description "Drop an open decision without a choice, with a Markdown reason"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
