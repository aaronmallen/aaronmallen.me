# frozen_string_literal: true

module MCP
  module Tools
    class UpdateWorkSession < Base
      description "Change when one of a task's work sessions started or ended. The task's total " \
                  "shifts by the difference"
      input_schema(API::Endpoints::UpdateWorkSession::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:update_work_session, input, server_context)
      end
    end
  end
end
