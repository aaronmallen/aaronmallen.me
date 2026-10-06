# frozen_string_literal: true

module MCP
  module Tools
    class PauseTask < Base
      description "Pause one task in progress: its work session ends and it goes back to open in the same " \
                  "sprint. start_task resumes it with a new session. " \
                  "#{Untrusted::TASK}"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
