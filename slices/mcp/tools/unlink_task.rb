# frozen_string_literal: true

module MCP
  module Tools
    class UnlinkTask < Base
      description "Remove the link between two tasks, whichever way it runs"
      input_schema(API::Endpoints::UnlinkTask::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:unlink_task, input, server_context)
      end
    end
  end
end
