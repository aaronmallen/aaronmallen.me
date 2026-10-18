# frozen_string_literal: true

module MCP
  module Tools
    class AddWorkSession < Base
      description "Add a finished work session to a task, with when it started and ended, for time nobody " \
                  "tracked. The task's total grows by its length. It never starts the task or changes its status. " \
                  "#{Untrusted::TASK}"
      endpoint
    end
  end
end
