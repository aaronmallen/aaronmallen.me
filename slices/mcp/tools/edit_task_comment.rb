# frozen_string_literal: true

module MCP
  module Tools
    class EditTaskComment < Base
      description "Replace the body of one comment on a task. A comment synced from GitHub or Linear cannot be edited"
      input_schema(API::Endpoints::EditTaskComment::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:edit_task_comment, input, server_context)
      end
    end
  end
end
