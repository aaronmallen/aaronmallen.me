# frozen_string_literal: true

module MCP
  module Tools
    class SetTaskTotal < Base
      description "Set the total time worked on one task, in hours and minutes, in place of what it has. " \
                  "Use it for time nobody tracked; later sessions add to it"
      input_schema(API::Endpoints::SetTaskTotal::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:set_task_total, input, server_context)
      end
    end
  end
end
