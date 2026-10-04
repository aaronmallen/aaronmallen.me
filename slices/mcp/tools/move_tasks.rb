# frozen_string_literal: true

module MCP
  module Tools
    class MoveTasks < Base
      description "Move up to 100 tasks to next, someday, external or today's sprint. One that is missing moves none"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
