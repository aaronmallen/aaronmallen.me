# frozen_string_literal: true

module MCP
  module Tools
    class UntagDecision < Base
      description "Take one private tag off a decision"
      input_schema(API::Endpoints::UntagDecision::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:untag_decision, input, server_context)
      end
    end
  end
end
