# frozen_string_literal: true

module MCP
  module Tools
    class UpdateWorkSession < Base
      description "Change when one of a task's work sessions started or ended. The task's total " \
                  "shifts by the difference"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
