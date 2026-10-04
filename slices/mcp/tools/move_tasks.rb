# frozen_string_literal: true

module MCP
  module Tools
    class MoveTasks < Base
      description "Move up to 100 tasks to next, someday, external or today's sprint. One that is missing moves none"
      input_schema(API::Endpoints::MoveTasks::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:move_tasks, input, server_context)
      end
    end
  end
end
