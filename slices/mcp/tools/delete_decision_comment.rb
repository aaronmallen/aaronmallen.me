# frozen_string_literal: true

module MCP
  module Tools
    class DeleteDecisionComment < Base
      description "Delete one comment on a decision. This cannot be undone"
      input_schema(API::Endpoints::DeleteDecisionComment::SCHEMA)
      scope OAuth::Scope::WRITE

      class << self
        def call(server_context:, **input) = hand_over(:delete_decision_comment, input, server_context)
      end
    end
  end
end
