# frozen_string_literal: true

module MCP
  module Tools
    class CaptureTask < Base
      description "Capture a new task, as the admin's Create Task form does. Name a sprint_on day to schedule it " \
                  "into that day's sprint"
      input_schema(API::Endpoints::CaptureTask::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:capture_task, input, server_context)
      end
    end
  end
end
