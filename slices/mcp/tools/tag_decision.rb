# frozen_string_literal: true

module MCP
  module Tools
    class TagDecision < Base
      description "Add private tags to a decision. The tags it already carries stay"
      input_schema(API::Endpoints::TagDecision::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:tag_decision, input, server_context)
      end
    end
  end
end
