# frozen_string_literal: true

module MCP
  module Tools
    class CompleteTasks < Base
      description "Mark up to 100 open or started tasks done at once, stamped with the time now. One that is " \
                  "missing or already closed completes none"
      input_schema(API::Endpoints::CompleteTasks::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:complete_tasks, input, server_context)
      end
    end
  end
end
