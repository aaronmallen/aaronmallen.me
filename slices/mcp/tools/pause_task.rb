# frozen_string_literal: true

module MCP
  module Tools
    class PauseTask < Base
      description "Pause one task in progress: its work session ends and it goes back to open in the same " \
                  "sprint. start_task resumes it with a new session"
      input_schema(API::Endpoints::PauseTask::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:pause_task, input, server_context)
      end
    end
  end
end
