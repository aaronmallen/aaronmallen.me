# frozen_string_literal: true

module MCP
  module Tools
    class DeleteTaskComment < Base
      description "Delete one comment on a task. A comment synced from GitHub or Linear cannot be deleted. " \
                  "This cannot be undone"
      input_schema(API::Endpoints::DeleteTaskComment::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:delete_task_comment, input, server_context)
      end
    end
  end
end
