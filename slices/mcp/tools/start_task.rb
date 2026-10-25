# frozen_string_literal: true

module MCP
  module Tools
    class StartTask < Base
      description "Start one task, or resume a paused one: it joins today's sprint, shows as in progress and " \
                  "opens a work session. It replies with the task's id, label, status and sprint day; read_task " \
                  "gives the full record."
      endpoint
    end
  end
end
