# frozen_string_literal: true

module MCP
  module Tools
    class DropSprint < Base
      description "Drop a sprint that has not started yet. Its synced tasks go back to external, the rest to next"
      endpoint
    end
  end
end
