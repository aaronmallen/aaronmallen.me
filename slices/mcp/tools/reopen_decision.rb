# frozen_string_literal: true

module MCP
  module Tools
    class ReopenDecision < Base
      description "Reopen a resolved or dropped decision with a Markdown reason. It clears the choice"
      input_schema(API::Endpoints::ReopenDecision::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:reopen_decision, input, server_context)
      end
    end
  end
end
