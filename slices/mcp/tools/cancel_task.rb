# frozen_string_literal: true

module MCP
  module Tools
    class CancelTask < Base
      description "Cancel one open or started task, stamped with the time now. It closes without counting as work " \
                  "done, so the activity feed leaves it out"
      input_schema(API::Endpoints::CancelTask::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:cancel_task, input, server_context)
      end
    end
  end
end
