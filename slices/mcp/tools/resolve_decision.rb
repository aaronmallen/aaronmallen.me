# frozen_string_literal: true

module MCP
  module Tools
    class ResolveDecision < Base
      description "Resolve an open decision with one of its own options and a Markdown reason for the choice"
      input_schema(API::Endpoints::ResolveDecision::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:resolve_decision, input, server_context)
      end
    end
  end
end
