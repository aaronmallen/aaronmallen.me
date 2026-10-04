# frozen_string_literal: true

module MCP
  module Tools
    class DeleteTask < Base
      description "Delete one task and every link to or from it. This cannot be undone"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
