# frozen_string_literal: true

module MCP
  module Tools
    class DropDecision < Base
      description "Drop an open decision without a choice, with a Markdown reason"
      input_schema(API::Endpoints::DropDecision::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:drop_decision, input, server_context)
      end
    end
  end
end
