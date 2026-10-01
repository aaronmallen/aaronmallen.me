# frozen_string_literal: true

module MCP
  module Tools
    class StartTask < Base
      description "Start one task: it joins today's sprint and shows as in progress"
      input_schema(API::Endpoints::StartTask::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:start_task, input, server_context)
      end
    end
  end
end
