# frozen_string_literal: true

module MCP
  module Tools
    class EditTaskComment < Base
      description "Replace the body of one comment on a task. A comment synced from GitHub or Linear cannot be edited"
      endpoint scope: OAuth::Scope::WRITE
    end
  end
end
