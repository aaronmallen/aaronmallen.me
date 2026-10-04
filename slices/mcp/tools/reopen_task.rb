# frozen_string_literal: true

module MCP
  module Tools
    class ReopenTask < Base
      description "Reopen one task, done, canceled or started: it goes back to open where it sits"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
