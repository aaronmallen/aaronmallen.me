# frozen_string_literal: true

module MCP
  module Tools
    class StartTask < Base
      description "Start one task, or resume a paused one: it joins today's sprint, shows as in progress and " \
                  "opens a work session. " \
                  "#{Untrusted::TASK}"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
