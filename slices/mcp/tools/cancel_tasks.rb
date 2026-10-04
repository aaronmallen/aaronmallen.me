# frozen_string_literal: true

module MCP
  module Tools
    class CancelTasks < Base
      description "Cancel up to 100 open tasks at once. One that is missing or already closed cancels none"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
