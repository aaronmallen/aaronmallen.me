# frozen_string_literal: true

module MCP
  module Tools
    class OpenDecision < Base
      description "Open a decision with a title and a Markdown problem statement, as the admin does. It starts open, " \
                  "ready for options"
      input_schema(API::Endpoints::OpenDecision::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:open_decision, input, server_context)
      end
    end
  end
end
