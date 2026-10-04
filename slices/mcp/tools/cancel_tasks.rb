# frozen_string_literal: true

module MCP
  module Tools
    class CancelTasks < Base
      description "Cancel up to 100 open tasks at once. One that is missing or already closed cancels none"
      input_schema(API::Endpoints::CancelTasks::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:cancel_tasks, input, server_context)
      end
    end
  end
end
