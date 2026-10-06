# frozen_string_literal: true

module MCP
  module Tools
    class DeleteTaskComment < Base
      description "Delete one comment on a task. A comment synced from GitHub or Linear cannot be deleted. " \
                  "This cannot be undone"
      endpoint scope: OAuth::Scope::DELETE
    end
  end
end
