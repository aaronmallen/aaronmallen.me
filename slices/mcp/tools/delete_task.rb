# frozen_string_literal: true

module MCP
  module Tools
    class DeleteTask < Base
      description "Delete one task and every link to or from it. This cannot be undone"
      input_schema(API::Endpoints::DeleteTask::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:delete_task, input, server_context)
      end
    end
  end
end
