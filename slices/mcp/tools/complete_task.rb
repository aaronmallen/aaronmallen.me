# frozen_string_literal: true

module MCP
  module Tools
    class CompleteTask < Base
      description "Mark one task done, stamped with the time now"
      input_schema(API::Endpoints::CompleteTask::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:complete_task, input, server_context)
      end
    end
  end
end
