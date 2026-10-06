# frozen_string_literal: true

module MCP
  module Tools
    class UnlinkTask < Base
      description "Remove the link between two tasks, whichever way it runs. " \
                  "#{Untrusted::TASK}"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
