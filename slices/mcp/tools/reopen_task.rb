# frozen_string_literal: true

module MCP
  module Tools
    class ReopenTask < Base
      description "Reopen one task, done, canceled or started: it goes back to open where it sits"
      input_schema(API::Endpoints::ReopenTask::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:reopen_task, input, server_context)
      end
    end
  end
end
