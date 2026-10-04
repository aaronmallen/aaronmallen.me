# frozen_string_literal: true

module MCP
  module Tools
    class DeleteTasks < Base
      description "Delete up to 100 tasks and every link to or from them. One that is missing deletes none. No undo"
      input_schema(API::Endpoints::DeleteTasks::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:delete_tasks, input, server_context)
      end
    end
  end
end
